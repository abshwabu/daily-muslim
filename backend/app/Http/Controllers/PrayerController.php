<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class PrayerController extends Controller
{
    /**
     * Calculate prayer times based on city and calculation method.
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function calculate(Request $request)
    {
        $request->validate([
            'city' => 'required|string',
            'country' => 'nullable|string',
            'method' => 'nullable|integer', // e.g., 2 for ISNA, 3 for MWL, etc.
        ]);

        $city = $request->input('city');
        $country = $request->input('country', ''); // Country is optional but helps
        $method = $request->input('method', 2); // Default to ISNA if not provided

        // AlAdhan API endpoint for prayer times by city
        // Documentation: https://aladhan.com/prayer-times-api#get-timings-by-city
        $response = Http::get("http://api.aladhan.com/v1/timingsByCity", [
            'city' => $city,
            'country' => $country,
            'method' => $method,
        ]);

        if ($response->successful()) {
            return response()->json($response->json());
        }

        return response()->json([
            'success' => false,
            'message' => 'Unable to fetch prayer times. Please check your city name.',
        ], 400);
    }

    /**
     * Get list of calculation methods.
     * 
     * @return \Illuminate\Http\JsonResponse
     */
    public function methods()
    {
        $response = Http::get("http://api.aladhan.com/v1/methods");
        
        if ($response->successful()) {
            return response()->json($response->json());
        }

        return response()->json([
            'success' => false,
            'message' => 'Unable to fetch calculation methods.',
        ], 400);
    }
}
