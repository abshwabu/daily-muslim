<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Task;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Carbon\Carbon;

class PlanningController extends Controller
{
    /**
     * Get the daily plan including prayer times and assigned tasks.
     */
    public function getDayPlan(Request $request, $date = null)
    {
        $date = $date ? Carbon::parse($date) : Carbon::today();
        $user = $request->user();

        // Default to a known city if not provided, or handle user preferences
        $city = $request->input('city', 'Addis Ababa'); 
        $country = $request->input('country', 'Ethiopia');
        $method = $request->input('method', 3); // MWL

        // Fetch Prayer Times (Local-first logic on client will cache this)
        $prayerResponse = Http::get("http://api.aladhan.com/v1/timingsByCity", [
            'city' => $city,
            'country' => $country,
            'method' => $method,
            'date' => $date->format('d-m-Y'),
        ]);

        $timings = [];
        if ($prayerResponse->successful()) {
            $timings = $prayerResponse->json()['data']['timings'];
        }

        // Fetch Tasks
        $tasks = Task::where('user_id', $user->id)
            ->whereDate('due_date', $date)
            ->get();

        // Group tasks by prayer anchor
        $groupedTasks = [
            'fajr' => $tasks->where('prayer_anchor', 'fajr')->values(),
            'dhuhr' => $tasks->where('prayer_anchor', 'dhuhr')->values(),
            'asr' => $tasks->where('prayer_anchor', 'asr')->values(),
            'maghrib' => $tasks->where('prayer_anchor', 'maghrib')->values(),
            'isha' => $tasks->where('prayer_anchor', 'isha')->values(),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'date' => $date->toDateString(),
                'prayer_times' => $timings,
                'sections' => $groupedTasks,
            ]
        ]);
    }

    /**
     * Manually move unfinished tasks to the current date.
     */
    public function rollover(Request $request)
    {
        $user = $request->user();
        $today = Carbon::today();

        $affectedRows = Task::where('user_id', $user->id)
            ->whereDate('due_date', '<', $today)
            ->where('is_completed', false)
            ->update(['due_date' => $today]);

        return response()->json([
            'success' => true,
            'message' => "Rolled over $affectedRows tasks to today.",
            'rolled_over_count' => $affectedRows
        ]);
    }

    /**
     * Store a new task.
     */
    public function storeTask(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'prayer_anchor' => 'required|in:fajr,dhuhr,asr,maghrib,isha',
            'due_date' => 'required|date',
            'is_high_priority' => 'nullable|boolean',
        ]);

        $task = $request->user()->tasks()->create($validated);

        return response()->json([
            'success' => true,
            'data' => $task
        ], 210);
    }

    /**
     * Toggle task completion status.
     */
    public function toggleTask(Request $request, Task $task)
    {
        if ($task->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $task->update(['is_completed' => !$task->is_completed]);

        return response()->json([
            'success' => true,
            'data' => $task
        ]);
    }
}
