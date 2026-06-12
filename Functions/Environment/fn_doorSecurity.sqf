if (!isServer) exitWith {};

[] spawn {
    private _OPEN_DIST       = 6;    // Distance déclenchement ouverture (inchangé)
    private _CLOSE_SAFE_DIST = 20;   // Rayon de sécurité : aucune unité dans ce périmètre pour autoriser la fermeture
    private _CLOSE_DELAY     = 25;   // Délai minimum (secondes) depuis l'ouverture avant de pouvoir refermer
    private _CHECK_FREQ      = 0.8;

    // Cache : [[_bldg, [_doorAnims, _lastOpenedTime, _cachedBldg, _isDoorOpen]], ...]
    private _doorCache = [];

    while {true} do {
        sleep _CHECK_FREQ;

        private _aiUnits = allUnits select {
            alive _x &&
            !isPlayer _x &&
            side _x != west &&
            vehicle _x == _x
        };

        if (_aiUnits isEqualTo []) then { continue; };

        private _currentTime = time;

        // Collecter les bâtiments proches de toutes les IA
        private _nearBuildings = [];
        {
            private _pos = getPosATL _x;
            {
                if !(_x in _nearBuildings) then {
                    _nearBuildings pushBack _x;
                };
            } forEach (nearestObjects [_pos, ["House", "Building"], _OPEN_DIST + 8]);
        } forEach _aiUnits;

        {
            private _bldg = _x;
            private _idx = _doorCache findIf { (_x select 0) == _bldg };
            private _bldgData = if (_idx != -1) then { (_doorCache select _idx) select 1 } else { [] };

            if (_bldgData isEqualTo []) then {
                private _anims = (animationNames _bldg) select { (toLowerANSI _x) find "door" >= 0 };
                // [anims, lastOpenedTime, cachedBldg, isDoorOpen]
                _bldgData = [_anims, 0, _bldg, false];
                _doorCache pushBack [_bldg, _bldgData];
                _idx = count _doorCache - 1;
            };

            _bldgData params [
                ["_doorAnims", [], [[]]],
                ["_lastOpened", 0, [0]],
                ["_cachedBldg", objNull, [objNull]],
                ["_isDoorOpen", false, [false]]
            ];

            if (_doorAnims isEqualTo []) then { continue; };

            // Vérifier si une IA non-BLUFOR est à portée d'ouverture
            private _aiNearDoor = _aiUnits findIf { _x distance _bldg < _OPEN_DIST } != -1;

            if (_aiNearDoor) then {
                // Ouvrir si fermée ou si porte pas encore complètement ouverte
                if (!_isDoorOpen || _currentTime - _lastOpened > 2) then {
                    {
                        private _phase = _bldg animationPhase _x;
                        if (_phase < 0.95) then {
                            _bldg animate [_x, 1, 0.8];
                            _bldg animateDoor [_x, 1, false];
                            private _soundPos = _bldg modelToWorld (getCenterOfMass _bldg);
                            playSound3D ["A3\Sounds_F\environment\doors\DoorMetalSingleOpen_1.wss", _bldg, false, _soundPos, 0.25, 0.8, 20];
                        };
                    } forEach _doorAnims;

                    // Marquer porte ouverte + horodater
                    _bldgData set [1, _currentTime];
                    _bldgData set [3, true];
                };
            }
            else {
                // Ne fermer que si :
                //   1. La porte est actuellement ouverte
                //   2. Assez de temps s'est écoulé depuis l'ouverture
                //   3. Aucune unité (IA non-BLUFOR OU joueur) dans le périmètre de sécurité élargi
                if (_isDoorOpen && _currentTime - _lastOpened > _CLOSE_DELAY) then {

                    private _anyUnitNear = false;

                    // Vérifier toutes les IA non-BLUFOR dans la zone élargie
                    { if (_x distance _bldg < _CLOSE_SAFE_DIST) exitWith { _anyUnitNear = true; }; } forEach _aiUnits;

                    // Vérifier les joueurs vivants de toutes factions
                    if (!_anyUnitNear) then {
                        { if (alive _x && _x distance _bldg < _CLOSE_SAFE_DIST) exitWith { _anyUnitNear = true; }; } forEach allPlayers;
                    };

                    if (!_anyUnitNear) then {
                        {
                            if (_bldg animationPhase _x > 0.05) then {
                                _bldg animate [_x, 0, 0.6];
                            };
                        } forEach _doorAnims;

                        // Marquer porte fermée — lastOpened remis à 0, pas de re-tentative immédiate
                        _bldgData set [1, 0];
                        _bldgData set [3, false];
                    };
                };
            };
        } forEach _nearBuildings;

        // Nettoyage du cache si trop de bâtiments en mémoire
        if (count _doorCache > 120) then {
            private _refPos = getPosATL (selectRandom _aiUnits);
            private _toRemove = [];
            {
                private _cachedObj = _x select 0;
                if (isNull _cachedObj || { _cachedObj distance2D _refPos > 300 }) then {
                    _toRemove pushBack _x;
                };
            } forEach _doorCache;
            _doorCache = _doorCache - _toRemove;
        };
    };
};
