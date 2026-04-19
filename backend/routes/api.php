<?php
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PrayerController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::get('/prayer-times', [PrayerController::class, 'calculate']);
Route::get('/prayer-methods', [PrayerController::class, 'methods']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
});
