import type { VercelRequest, VercelResponse } from "@vercel/node";
import { getToken, freshAccessToken, fetchMappedActivities } from "../_lib/strava";

// GET ?deviceKey=... — read the device's Strava token from Supabase (refreshing
// it server-side if expired), fetch recent activities, and return them mapped to
// the app's workout shape. The app never handles the Strava access token.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  const deviceKey = (req.query.deviceKey ?? "").toString();
  if (!deviceKey) {
    res.status(400).json({ error: "missing_device_key" });
    return;
  }

  try {
    const row = await getToken(deviceKey);
    if (!row) {
      res.status(200).json({ connected: false, activities: [] });
      return;
    }
    const accessToken = await freshAccessToken(row);
    const activities = await fetchMappedActivities(accessToken);
    res.status(200).json({ connected: true, activities });
  } catch (err) {
    res.status(502).json({ error: "activities_failed", detail: (err as Error).message });
  }
}
