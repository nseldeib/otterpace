import type { VercelRequest, VercelResponse } from "@vercel/node";

// Strava redirects the browser here after the user approves (Authorization
// Callback Domain = otterpace.com). We bounce straight back into the app's
// custom scheme so ASWebAuthenticationSession can capture the code. The device
// key rides along in `state` so the exchange step knows whose tokens to store.
export default function handler(req: VercelRequest, res: VercelResponse) {
  const { code, state, error } = req.query as Record<string, string | undefined>;
  const params = new URLSearchParams();
  if (error) params.set("error", error);
  else if (code) params.set("code", code);
  else params.set("error", "no_code");
  if (state) params.set("state", state);

  res.statusCode = 302;
  res.setHeader("Location", `otterpace://strava-callback?${params.toString()}`);
  res.end();
}
