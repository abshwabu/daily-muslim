<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('tasks', function (Blueprint $row) {
            $row->id();
            $row->foreignId('user_id')->constrained()->onDelete('cascade');
            $row->string('title');
            $row->enum('prayer_anchor', ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
            $row->date('due_date');
            $row->boolean('is_completed')->default(false);
            $row->boolean('is_high_priority')->default(false);
            $row->timestamps();
            
            $row->index(['user_id', 'due_date']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('tasks');
    }
};
