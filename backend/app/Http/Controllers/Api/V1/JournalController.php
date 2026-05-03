<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\JournalEntry;
use Illuminate\Http\Request;
use Carbon\Carbon;

class JournalController extends Controller
{
    /**
     * Display a listing of journal entries for the authenticated user.
     */
    public function index(Request $request)
    {
        $entries = $request->user()->journalEntries()
            ->orderBy('date', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $entries
        ]);
    }

    /**
     * Store a newly created journal entry in storage.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'content' => 'required|string',
            'date' => 'required|date',
            'prompt' => 'nullable|string|max:255',
        ]);

        $entry = $request->user()->journalEntries()->updateOrCreate(
            ['date' => $validated['date']],
            ['content' => $validated['content'], 'prompt' => $validated['prompt'] ?? null]
        );

        return response()->json([
            'success' => true,
            'data' => $entry
        ]);
    }

    /**
     * Display the specified journal entry.
     */
    public function show(Request $request, $date)
    {
        $entry = $request->user()->journalEntries()
            ->where('date', $date)
            ->first();

        if (!$entry) {
            return response()->json([
                'success' => false,
                'message' => 'Entry not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $entry
        ]);
    }

    /**
     * Get the prompt of the day.
     */
    public function getPrompt()
    {
        $prompts = [
            "What are you grateful for in this quiet moment?",
            "What is one thing you want to focus on today?",
            "How did you feel during your last prayer?",
            "What was the most peaceful part of your day yesterday?",
            "Is there someone you want to make Du'a for today?",
            "What is a small victory you achieved recently?",
            "How can you bring more mindfulness to your tasks today?",
        ];

        // Use the day of the year to pick a prompt so it's consistent for everyone on the same day
        $index = date('z') % count($prompts);
        
        return response()->json([
            'success' => true,
            'data' => [
                'prompt' => $prompts[$index]
            ]
        ]);
    }

    /**
     * Remove the specified journal entry from storage.
     */
    public function destroy(Request $request, JournalEntry $journalEntry)
    {
        if ($journalEntry->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $journalEntry->delete();

        return response()->json([
            'success' => true,
            'message' => 'Entry deleted successfully'
        ]);
    }
}
