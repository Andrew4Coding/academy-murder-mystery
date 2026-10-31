export const takeoverPage = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Moonfall take over</title>
<style>
  :root { color-scheme: light dark; font-family: -apple-system, system-ui, sans-serif; }
  body { margin: 0; padding: 24px; max-width: 28rem; margin-inline: auto; line-height: 1.5; }
  h1 { font-size: 1.5rem; }
  label { display: block; font-weight: 600; margin-block: 16px 6px; }
  input { font: inherit; font-size: 1.5rem; letter-spacing: 0.3em; padding: 10px 12px; width: 100%; box-sizing: border-box; }
  button { font: inherit; font-weight: 600; margin-top: 16px; padding: 12px 20px; min-height: 44px; width: 100%; }
  #status { margin-top: 16px; font-weight: 600; }
</style>
</head>
<body>
<main>
  <h1>Take over in the cloud</h1>
  <p>Use this only when the Mac host is down. It activates the latest backup on this server and moves every phone to it.</p>
  <form id="form">
    <label for="pin">OC PIN</label>
    <input id="pin" name="pin" inputmode="numeric" autocomplete="off" maxlength="12" required>
    <button type="submit">Take over</button>
  </form>
  <p id="status" role="status" aria-live="polite"></p>
</main>
<script>
const form = document.getElementById("form");
const status = document.getElementById("status");
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  status.textContent = "Working...";
  try {
    const response = await fetch("/takeover", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pin: document.getElementById("pin").value })
    });
    const body = await response.json().catch(() => ({}));
    status.textContent = response.ok ? "Done. The cloud host is now active." : "Failed: " + (body.error || response.status);
  } catch (error) {
    status.textContent = "Failed: could not reach the server.";
  }
});
</script>
</body>
</html>
`;
