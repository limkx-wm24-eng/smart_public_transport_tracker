const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const googleHeaders = (apiKey: string, fieldMask: string) => ({
  'Content-Type': 'application/json',
  'X-Goog-Api-Key': apiKey,
  'X-Goog-FieldMask': fieldMask,
});

async function googleJson(response: Response) {
  if (response.ok) return response.json();
  const body = await response.json().catch(() => ({}));
  const message = body?.error?.message ?? `Google Maps request failed (${response.status}).`;
  throw new Error(message);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY');
    if (!apiKey) throw new Error('GOOGLE_MAPS_API_KEY is not configured.');
    const { action, query, origin, destination, preference } = await request.json();

    if (action === 'searchPlaces') {
      if (typeof query !== 'string' || query.trim().length < 2) {
        return Response.json({ places: [] }, { headers: corsHeaders });
      }
      const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: googleHeaders(apiKey, 'places.id,places.displayName,places.formattedAddress,places.location'),
        body: JSON.stringify({
          textQuery: `${query.trim()}, Malaysia`,
          maxResultCount: 5,
          languageCode: 'en',
        }),
      });
      const body = await googleJson(response);
      const places = (body.places ?? [])
        .filter((place: { location?: { latitude?: number; longitude?: number } }) =>
          Number.isFinite(place.location?.latitude) && Number.isFinite(place.location?.longitude))
        .map((place: { id?: string; displayName?: { text?: string }; formattedAddress?: string; location: { latitude: number; longitude: number } }) => ({
          id: place.id,
          name: place.displayName?.text ?? place.formattedAddress ?? 'Unnamed place',
          address: place.formattedAddress ?? '',
          latitude: place.location.latitude,
          longitude: place.location.longitude,
        }));
      return Response.json({ places }, { headers: corsHeaders });
    }

    if (action === 'findTransitRoutes') {
      if (![origin, destination].every((point) => Number.isFinite(point?.latitude) && Number.isFinite(point?.longitude))) {
        return Response.json({ error: 'A valid start and destination are required.' }, { status: 400, headers: corsHeaders });
      }
      const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST',
        headers: googleHeaders(apiKey, 'routes.duration,routes.localizedValues,routes.legs.steps.travelMode,routes.legs.steps.localizedValues,routes.legs.steps.navigationInstruction.instructions,routes.legs.steps.transitDetails'),
        body: JSON.stringify({
          origin: { location: { latLng: { latitude: origin.latitude, longitude: origin.longitude } } },
          destination: { location: { latLng: { latitude: destination.latitude, longitude: destination.longitude } } },
          travelMode: 'TRANSIT',
          computeAlternativeRoutes: true,
          languageCode: 'en-MY',
          transitPreferences: {
            routingPreference: preference === 'fewestTransfers' ? 'FEWER_TRANSFERS' : 'LESS_WALKING',
            allowedTravelModes: ['BUS', 'SUBWAY', 'TRAIN', 'LIGHT_RAIL', 'RAIL'],
          },
        }),
      });
      const body = await googleJson(response);
      return Response.json({ routes: body.routes ?? [] }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Unknown planner action.' }, { status: 400, headers: corsHeaders });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Planner unavailable.' }, { status: 500, headers: corsHeaders });
  }
});
