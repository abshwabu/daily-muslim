<?php
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PrayerController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\V1\PlanningController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::get('/prayer-times', [PrayerController::class, 'calculate']);
Route::get('/prayer-methods', [PrayerController::class, 'methods']);

Route::middleware('auth:sanctum')->group(function () {
    Route::prefix('v1')->group(function () {
        Route::get('/plan/{date?}', [PlanningController::class, 'getDayPlan']);
        Route::get('/templates', [PlanningController::class, 'getTemplates']);
        Route::post('/tasks/rollover', [PlanningController::class, 'rollover']);
        Route::post('/tasks', [PlanningController::class, 'storeTask']);
        Route::patch('/tasks/{task}/toggle', [PlanningController::class, 'toggleTask']);
        Route::post('/tasks/template/toggle', [PlanningController::class, 'toggleTemplateTask']);
    });

    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
});
