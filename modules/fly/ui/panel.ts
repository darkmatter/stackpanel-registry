import { getContext, runAction } from "@stackpanel/extension-sdk";

interface FlyApp {
  app: string;
  appName: string;
  region: string;
  memory: string;
}

function isFlyApp(value: unknown): value is FlyApp {
  return typeof value === "object" && value !== null
    && "app" in value && typeof value.app === "string"
    && "appName" in value && typeof value.appName === "string"
    && "region" in value && typeof value.region === "string"
    && "memory" in value && typeof value.memory === "string";
}

function isInventory(value: unknown): value is { organization: string | null; defaultRegion: string; apps: FlyApp[] } {
  return typeof value === "object" && value !== null
    && "organization" in value && (value.organization === null || typeof value.organization === "string")
    && "defaultRegion" in value && typeof value.defaultRegion === "string"
    && "apps" in value && Array.isArray(value.apps) && value.apps.every(isFlyApp);
}

async function mount() {
  const controls = document.querySelector<HTMLElement>("#controls");
  const app = document.querySelector<HTMLSelectElement>("#app");
  const statusButton = document.querySelector<HTMLButtonElement>("#status");
  const scope = document.querySelector<HTMLElement>("#scope");
  const output = document.querySelector<HTMLElement>("#output");
  if (!controls || !app || !statusButton || !scope || !output) throw new Error("Fly panel layout is incomplete.");

  const context = await getContext();
  if (!context.permissions.includes("actions:run")) throw new Error("Fly actions are not permitted in this panel.");
  const inventory = await runAction("apps", {});
  if (inventory.exitCode !== 0) throw new Error(inventory.stderr || `Listing apps exited with ${inventory.exitCode}.`);
  const data = inventory.json;
  if (!isInventory(data)) throw new Error("The Fly apps action returned an invalid inventory.");
  scope.textContent = `Organization: ${data.organization ?? "Fly default"} · Default region: ${data.defaultRegion}`;
  if (!data.apps.length) {
    output.textContent = 'No Fly apps configured. Enable deployment and set the app’s deployment.host to "fly".';
    return;
  }
  for (const item of data.apps) {
    app.add(new Option(`${item.app} → ${item.appName} (${item.region}, ${item.memory})`, item.app));
  }
  controls.hidden = false;
  app.addEventListener("change", () => { output.textContent = ""; });
  statusButton.addEventListener("click", async () => {
    app.disabled = true;
    statusButton.disabled = true;
    output.textContent = `Checking ${app.value}…`;
    try {
      const result = await runAction("status", { app: app.value });
      const text = [result.stdout, result.stderr].filter(Boolean).join("\n");
      output.textContent = result.exitCode === 0 ? text : `Fly status failed (exit ${result.exitCode}).\n${text}`;
    } catch (error) {
      output.textContent = error instanceof Error ? error.message : String(error);
    } finally {
      app.disabled = false;
      statusButton.disabled = false;
    }
  });
}

void mount().catch((error: unknown) => {
  const scope = document.querySelector("#scope");
  if (scope) scope.textContent = error instanceof Error ? error.message : String(error);
});
