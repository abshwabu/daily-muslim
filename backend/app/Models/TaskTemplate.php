<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TaskTemplate extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'category',
        'prayer_anchor',
        'day_of_week',
    ];

    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class, 'template_id');
    }
}
