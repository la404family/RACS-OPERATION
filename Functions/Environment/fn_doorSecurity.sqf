/*
    File: fn_doorSecurity.sqf
    Description: Ouverture/fermeture réaliste et anticipée des portes pour IA non-BLUFOR.
                 Évite que l'IA ne passe à travers les portes fermées.
    Locality: Serveur uniquement
*/

if (!isServer) exitWith {};

[] spawn {
    private _OPEN_DIST     = 6;      // Distance à laquelle l'IA "ouvre" la porte
    private _CLOSE_DELAY   = 12;     // Secondes avant fermeture automatique
    private _CHECK_FREQ    = 0.8;    // Fréquence globale (optimisée)

    private _doorCache     = createHashMap;  // [building, [doorAnims, lastOpenedTime]]

    while {true} do {
        sleep _CHECK_FREQ;

        // Récupération des IA concernées (non-BLUFOR, vivantes, à pied)
        private _aiUnits = allUnits select {
            alive _x &&
            !isPlayer _x &&
            side _x != west &&
            vehicle _x == _x
        };

        if (_aiUnits isEqualTo []) then { continue; };

        private _currentTime = time;

        // --- Collecte intelligente des bâtiments ---
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
            private _bldgData = _doorCache getOrDefault [_bldg, []];

            // Cache des animations de portes
            if (_bldgData isEqualTo []) then {
                private _anims = (animationNames _bldg) select { (toLowerANSI _x) find "door" >= 0 };
                _bldgData = [_anims, 0]; 
                _doorCache set [_bldg, _bldgData];
            };

            _bldgData params ["_doorAnims", "_lastOpened"];

            if (_doorAnims isEqualTo []) then { continue; };

            private _aiNearby = _aiUnits findIf { _x distance _bldg < _OPEN_DIST } != -1;

            if (_aiNearby) then {
                // === OUVERTURE RÉALISTE ===
                if (_currentTime - _lastOpened > 1.5) then {  // Cooldown anti-spam
                    {
                        private _phase = _bldg animationPhase _x;
                        if (_phase < 0.95) then {
                            // Ouverture progressive + son
                            _bldg animate [_x, 1, 0.8];           
                            _bldg animateDoor [_x, 1, false];     

                            // Son d'ouverture (localisé)
                            private _soundPos = _bldg modelToWorld (getCenterOfMass _bldg);
                            playSound3D ["A3\Sounds_F\environment\doors\DoorMetalSingleOpen_1.wss", _bldg, false, _soundPos, 1.2, 1, 35];
                        };
                    } forEach _doorAnims;

                    _bldgData set [1, _currentTime];
                    _doorCache set [_bldg, _bldgData];
                };
            } 
            else {
                // === FERMETURE PROGRESSIVE ===
                if (_currentTime - _lastOpened > _CLOSE_DELAY) then {
                    {
                        if (_bldg animationPhase _x > 0.05) then {
                            _bldg animate [_x, 0, 0.6];  // Fermeture un peu plus lente
                        };
                    } forEach _doorAnims;

                    // Mise à jour du timestamp
                    _bldgData set [1, _currentTime - _CLOSE_DELAY + 3];
                    _doorCache set [_bldg, _bldgData];
                };
            };
        } forEach _nearBuildings;

        // Nettoyage léger du cache (bâtiments trop loin)
        if (count _doorCache > 120) then {
            private _refPos = getPosATL (selectRandom _aiUnits);
            private _toRemove = [];
            {
                if (_x distance2D _refPos > 300) then {
                    _toRemove pushBack _x;
                };
            } forEach (keys _doorCache);
            { _doorCache deleteAt _x; } forEach _toRemove;
        };
    };
};
