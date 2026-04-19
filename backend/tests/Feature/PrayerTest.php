<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PrayerTest extends TestCase
{
    public function test_can_fetch_prayer_times()
    {
        $response = $this->getJson('/api/prayer-times?city=Addis+Ababa&method=2');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'code',
                'status',
                'data' => [
                    'timings' => [
                        'Fajr',
                        'Dhuhr',
                        'Asr',
                        'Maghrib',
                        'Isha',
                    ],
                    'meta' => [
                        'method' => [
                            'id',
                            'name',
                        ],
                    ],
                ],
            ]);
    }

    public function test_can_fetch_prayer_methods()
    {
        $response = $this->getJson('/api/prayer-methods');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'code',
                'status',
                'data',
            ]);
    }
}
