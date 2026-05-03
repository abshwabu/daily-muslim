<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JournalEntry extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'content',
        'date',
        'prompt',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
