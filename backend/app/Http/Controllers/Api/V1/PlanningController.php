<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Task;
use App\Models\TaskTemplate;
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

        // Fetch Templates (Cache for 24 hours, but we filter them per request)
        $templatesArray = cache()->remember('task_templates_array', 86400, function() {
            return TaskTemplate::all()->toArray();
        });

        $dayOfWeek = $date->format('l'); // e.g., 'Friday'
        $templates = collect($templatesArray)->filter(function ($template) use ($dayOfWeek) {
            return is_null($template['day_of_week']) || $template['day_of_week'] === $dayOfWeek;
        });

        // Fetch Tasks
        $tasks = Task::where('user_id', $user->id)
            ->whereDate('due_date', $date)
            ->get();

        $sections = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
        $groupedTasks = [];

        foreach ($sections as $section) {
            $sectionTasks = [];
            
            // Add templates for this section
            foreach ($templates->where('prayer_anchor', $section) as $template) {
                $userTask = $tasks->where('template_id', $template['id'])->first();
                $sectionTasks[] = [
                    'id' => $userTask?->id,
                    'template_id' => $template['id'],
                    'title' => $template['title'],
                    'description' => $template['description'] ?? null,
                    'category' => $template['category'],
                    'prayer_anchor' => $template['prayer_anchor'],
                    'due_date' => $date->toDateString(),
                    'is_completed' => $userTask?->is_completed ?? false,
                    'is_high_priority' => $userTask?->is_high_priority ?? false,
                    'is_template' => true,
                ];
            }

            // Add user personal tasks for this section (those without template_id)
            foreach ($tasks->where('prayer_anchor', $section)->whereNull('template_id') as $task) {
                $sectionTasks[] = [
                    'id' => $task->id,
                    'template_id' => null,
                    'title' => $task->title,
                    'description' => $task->description,
                    'category' => 'Personal',
                    'prayer_anchor' => $task->prayer_anchor,
                    'due_date' => $task->due_date->toDateString(),
                    'is_completed' => $task->is_completed,
                    'is_high_priority' => $task->is_high_priority,
                    'is_template' => false,
                ];
            }

            $groupedTasks[$section] = $sectionTasks;
        }

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
     * Get all task templates.
     */
    public function getTemplates()
    {
        return response()->json([
            'success' => true,
            'data' => TaskTemplate::all()
        ]);
    }

    /**
     * Manually move unfinished tasks to the current date.
     */
    public function rollover(Request $request)
    {
        $user = $request->user();
        $today = Carbon::today();

        // Only rollover personal tasks, not template-based habits
        $affectedRows = Task::where('user_id', $user->id)
            ->whereNull('template_id')
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

    /**
     * Toggle a template-based task.
     */
    public function toggleTemplateTask(Request $request)
    {
        $validated = $request->validate([
            'template_id' => 'required|exists:task_templates,id',
            'date' => 'required|date',
        ]);

        $user = $request->user();
        $date = Carbon::parse($validated['date']);

        $task = Task::where('user_id', $user->id)
            ->where('template_id', $validated['template_id'])
            ->whereDate('due_date', $date)
            ->first();

        if ($task) {
            $task->update(['is_completed' => !$task->is_completed]);
        } else {
            $template = TaskTemplate::find($validated['template_id']);
            $task = Task::create([
                'user_id' => $user->id,
                'template_id' => $template->id,
                'title' => $template->title,
                'prayer_anchor' => $template->prayer_anchor,
                'due_date' => $date,
                'is_completed' => true,
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => $task
        ]);
    }
}
