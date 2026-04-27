<?php

namespace Database\Seeders;

use App\Models\TaskTemplate;
use Illuminate\Database\Seeder;

class TaskTemplateSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $templates = [
            // Daily habits
            [
                'title' => 'Morning Azkar',
                'description' => 'Recite the morning adhkar for protection and blessing.',
                'category' => 'Azkar',
                'prayer_anchor' => 'fajr',
                'day_of_week' => null,
            ],
            [
                'title' => 'Evening Azkar',
                'description' => 'Recite the evening adhkar for protection and peace.',
                'category' => 'Azkar',
                'prayer_anchor' => 'maghrib',
                'day_of_week' => null,
            ],
            [
                'title' => 'Post-Prayer Dhikr',
                'description' => 'SubhanAllah, Alhamdulillah, Allahu Akbar (33x each) after prayer.',
                'category' => 'Azkar',
                'prayer_anchor' => 'fajr',
                'day_of_week' => null,
            ],
            [
                'title' => 'Post-Prayer Dhikr',
                'description' => 'SubhanAllah, Alhamdulillah, Allahu Akbar (33x each) after prayer.',
                'category' => 'Azkar',
                'prayer_anchor' => 'dhuhr',
                'day_of_week' => null,
            ],
            [
                'title' => 'Post-Prayer Dhikr',
                'description' => 'SubhanAllah, Alhamdulillah, Allahu Akbar (33x each) after prayer.',
                'category' => 'Azkar',
                'prayer_anchor' => 'asr',
                'day_of_week' => null,
            ],
            [
                'title' => 'Post-Prayer Dhikr',
                'description' => 'SubhanAllah, Alhamdulillah, Allahu Akbar (33x each) after prayer.',
                'category' => 'Azkar',
                'prayer_anchor' => 'maghrib',
                'day_of_week' => null,
            ],
            [
                'title' => 'Post-Prayer Dhikr',
                'description' => 'SubhanAllah, Alhamdulillah, Allahu Akbar (33x each) after prayer.',
                'category' => 'Azkar',
                'prayer_anchor' => 'isha',
                'day_of_week' => null,
            ],
            [
                'title' => 'Tahajjud Prayer',
                'description' => 'The night prayer is one of the best voluntary acts.',
                'category' => 'Sunnah',
                'prayer_anchor' => 'fajr',
                'day_of_week' => null,
            ],
            [
                'title' => 'Duha Prayer',
                'description' => 'Performed after sunrise until before Dhuhr.',
                'category' => 'Sunnah',
                'prayer_anchor' => 'dhuhr',
                'day_of_week' => null,
            ],

            // Weekly habits
            [
                'title' => 'Surah Al-Kahf',
                'description' => 'Recite Surah Al-Kahf for light until the next Friday.',
                'category' => 'Quran',
                'prayer_anchor' => 'dhuhr',
                'day_of_week' => 'Friday',
            ],
            [
                'title' => 'Sunnah Fasting',
                'description' => 'Fasting on Mondays is a Sunnah of the Prophet (SAW).',
                'category' => 'Sunnah',
                'prayer_anchor' => 'fajr',
                'day_of_week' => 'Monday',
            ],
            [
                'title' => 'Sunnah Fasting',
                'description' => 'Fasting on Thursdays is a Sunnah of the Prophet (SAW).',
                'category' => 'Sunnah',
                'prayer_anchor' => 'fajr',
                'day_of_week' => 'Thursday',
            ],
        ];

        foreach ($templates as $template) {
            TaskTemplate::updateOrCreate(
                ['title' => $template['title'], 'prayer_anchor' => $template['prayer_anchor'], 'day_of_week' => $template['day_of_week']],
                $template
            );
        }
    }
}
