<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Task extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'template_id',
        'title',
        'prayer_anchor',
        'due_date',
        'is_completed',
        'is_high_priority',
    ];

    protected $casts = [
        'due_date' => 'date',
        'is_completed' => 'boolean',
        'is_high_priority' => 'boolean',
        'template_id' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function taskTemplate(): BelongsTo
    {
        return $this->belongsTo(TaskTemplate::class, 'template_id');
    }
}
