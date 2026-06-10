if (!isServer) exitWith {};

private _d = date;
private _hour = 3 + floor (random 18);
private _minute = floor (random 60);
if (_hour == 20) then { _minute = floor (random 31); };

setDate [_d select 0, _d select 1, _d select 2, _hour, _minute];

diag_log format ["[LL][Weather] Heure de mission : %1h%2", _hour, _minute];

private _p = selectRandom [
    [0.00, 0.25, 0.04, 0.00,  0.0,  4.0, "Clair"],
    [0.00, 0.25, 0.02, 0.00,  6.0, 18.0, "Clair venteux"],
    [0.00, 0.20, 0.01, 0.00, 20.0, 35.0, "Clair tempete"],
    [0.30, 0.60, 0.07, 0.00,  0.0,  7.0, "Nuageux"],
    [0.60, 0.85, 0.10, 0.05,  0.0, 10.0, "Couvert"],
    [0.75, 0.92, 0.12, 0.35,  0.0, 14.0, "Pluie légère"],
    [0.90, 1.00, 0.15, 0.80,  0.0, 25.0, "Tempête"],
    [0.00, 0.30, 0.15, 0.00,  0.0,  2.0, "Brume matinale"]
];

_p params ["_overcastMin", "_overcastMax", "_fogMax", "_rainMax", "_windMin", "_windMax", "_label"];

private _overcast = _overcastMin + random (_overcastMax - _overcastMin);
private _fog      = random _fogMax;
private _rain     = random _rainMax;

private _windAngle = random 360;
private _windSpeed = _windMin + random (_windMax - _windMin);
private _windX     = _windSpeed * sin _windAngle;
private _windY     = _windSpeed * cos _windAngle;

skipTime -24;
86400 setOvercast _overcast;
skipTime 24;

0 setFog _fog;
0 setRain _rain;
setWind [_windX, _windY, true];
forceWeatherChange;

diag_log format [
    "[LL][Weather] Preset=%1 | overcast=%2 | fog=%3 | rain=%4 | vent=%5 m/s @%6 deg",
    _label, _overcast, _fog, _rain, _windSpeed, _windAngle
];
