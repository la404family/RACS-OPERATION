if (!hasInterface) exitWith {};

params [
    ["_center", [0,0,0], [[]]],
    ["_maxRadius", 40, [0]],
    ["_duration", 3, [0]],
    ["_color", [0.8, 0.8, 0.8, 1], [[]]]
];

private _source = "#particlesource" createVehicleLocal _center;

_source setParticleCircle [0.1, [2, 2, 0.1]];
_source setParticleRandom [0.3, [0.2, 0.2, 0.1], [0.3, 0.3, 0.1], 0, 0.3, [0,0,0,0.05], 0, 0];

_source setParticleParams [
    ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard",
    1, 2.5, [0,0,0], [0,0,0], 0, 1.275, 1, 0.2,
    [1.5, 6, 10], 
    [
        [_color select 0, _color select 1, _color select 2, (_color select 3) * 0.8],
        [_color select 0, _color select 1, _color select 2, (_color select 3) * 0.4],
        [_color select 0, _color select 1, _color select 2, 0]
    ],
    [0.5], 0.1, 0, "", "", _source
];

_source setDropInterval 0.01;

private _startTime = time;
private _radius = 0.1;

while { _radius < _maxRadius && (time - _startTime) < _duration } do {
    private _progress = (time - _startTime) / _duration;
    _radius = 0.1 + (_maxRadius - 0.1) * _progress;

    _source setParticleCircle [_radius, [2 * (1 - _progress), 2 * (1 - _progress), 0.1]];
    sleep 0.03;
};

deleteVehicle _source;
