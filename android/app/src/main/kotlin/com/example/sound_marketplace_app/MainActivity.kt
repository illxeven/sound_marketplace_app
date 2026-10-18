package com.example.sound_marketplace_app

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity covers both needs:
//  - audio_service (background playback, lock-screen controls) needs an AudioService* activity
//  - flutter_stripe's PaymentSheet needs a FragmentActivity (plain FlutterActivity crashes it)
class MainActivity : AudioServiceFragmentActivity()
