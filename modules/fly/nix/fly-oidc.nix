# Optional Fly Machine entrypoint helpers. Nothing here runs during evaluation,
# on the Studio host, or unless the consuming container uses the entrypoint.
{ pkgs }:
let
  inherit (pkgs.lib) escapeShellArg optional optionalString;
in
{
  mkEnvConfig =
    {
      roleArn,
      tokenFile ? "/tmp/fly-oidc-token",
      awsRegion ? "us-west-2",
    }:
    {
      AWS_ROLE_ARN = roleArn;
      AWS_WEB_IDENTITY_TOKEN_FILE = tokenFile;
      AWS_REGION = awsRegion;
    };

  mkEntrypoint =
    {
      sessionPrefix,
      chamberService ? "",
      tokenFile ? "/tmp/fly-oidc-token",
      durationSeconds ? 3600,
      maxAttempts ? 10,
      retryDelaySecs ? 10,
      fileWaitSecs ? 30,
      socketWaitSecs ? 60,
      extraRuntimeInputs ? [ ],
      preAuthHook ? "",
      postAuthHook ? "",
      skipChamber ? false,
      debug ? false,
    }:
    assert
      skipChamber
      || chamberService != ""
      || throw "flyOidc.mkEntrypoint requires chamberService or skipChamber";
    pkgs.writeShellApplication {
      name = "fly-oidc-entrypoint";
      runtimeInputs = [
        pkgs.awscli2
        pkgs.coreutils
        pkgs.curl
        pkgs.jq
      ]
      ++ optional (!skipChamber) pkgs.chamber
      ++ extraRuntimeInputs;
      text = ''
        ${preAuthHook}
        : "''${AWS_ROLE_ARN:?Set AWS_ROLE_ARN to an IAM role that trusts this Fly Machine}"
        if [[ $# -eq 0 ]]; then echo 'Missing application command' >&2; exit 2; fi

        # Prefer the identity file supplied by Fly init. Never log the token,
        # its claims, or STS responses, even when diagnostics are enabled.
        identity="''${AWS_WEB_IDENTITY_TOKEN_FILE:-/.fly/oidc_token}"
        for ((i=0; i < ${toString fileWaitSecs}; i++)); do
          [[ -s "$identity" ]] && break
          sleep 1
        done
        if [[ ! -s "$identity" ]]; then
          ${optionalString debug "echo 'Waiting for the Fly Machine identity socket' >&2"}
          for ((i=0; i < ${toString socketWaitSecs}; i++)); do
            [[ -S /.fly/api ]] && break
            sleep 1
          done
          [[ -S /.fly/api ]] || { echo 'Fly Machine identity socket unavailable' >&2; exit 1; }
          identity=${escapeShellArg tokenFile}
          umask 077
          tmp=$(mktemp -- "$identity.XXXXXXXX")
          trap 'rm -f -- "$tmp"' EXIT
          acquired=false
          for ((i=0; i < ${toString maxAttempts}; i++)); do
            if curl --fail --silent --show-error --max-time 10 --unix-socket /.fly/api \
              -H 'Content-Type: application/json' -d '{"aud":"sts.amazonaws.com","aws_principal_tags":true}' \
              http://localhost/v1/tokens/oidc | jq -ejRs '
                rtrimstr("\n") | if startswith("{") then fromjson.token else . end |
                select(type == "string" and test("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"))' > "$tmp"; then
              mv -fT -- "$tmp" "$identity"
              acquired=true
              break
            fi
            sleep ${toString retryDelaySecs}
          done
          [[ "$acquired" == true ]] || { echo 'Fly Machine identity request failed' >&2; exit 1; }
          trap - EXIT
        fi

        export AWS_WEB_IDENTITY_TOKEN_FILE="$identity"
        ${optionalString debug "echo 'Exchanging Fly Machine identity for an AWS session' >&2"}
        credentials=$(aws sts assume-role-with-web-identity \
          --role-arn "$AWS_ROLE_ARN" \
          --role-session-name ${escapeShellArg sessionPrefix}"-flyio-$(date +%s)" \
          --web-identity-token "file://$identity" \
          --duration-seconds ${toString durationSeconds} --output json)
        AWS_ACCESS_KEY_ID=$(jq -er '.Credentials.AccessKeyId' <<< "$credentials")
        AWS_SECRET_ACCESS_KEY=$(jq -er '.Credentials.SecretAccessKey' <<< "$credentials")
        AWS_SESSION_TOKEN=$(jq -er '.Credentials.SessionToken' <<< "$credentials")
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        unset credentials
        ${postAuthHook}
        ${
          if skipChamber then
            ''exec "$@"''
          else
            ''exec chamber exec ${escapeShellArg chamberService} -- "$@"''
        }
      '';
    };
}
