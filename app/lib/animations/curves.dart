import 'package:flutter/animation.dart';

// Custom cubic curves for Termex
const Curve termexEnter  = Cubic(0.2, 0, 0, 1);       // entering
const Curve termexExit   = Cubic(0.4, 0, 1, 1);        // exiting
const Curve termexSpring = Cubic(0.34, 1.56, 0.64, 1); // spring-like overshoot
