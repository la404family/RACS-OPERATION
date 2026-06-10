if (!isServer) exitWith {};

params [
    ["_type",     "CAS",   [""]],
    ["_pos",      [0,0,0], [[]]],
    ["_caller",   objNull, [objNull]],
    ["_priority", 1,       [0]]
];

if (_type == "CAS" && { time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) }) exitWith {
    private _rem = ceil ((missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) - time);
    (format ["QG : Appui aérien en cooldown, encore %1 secondes.", _rem]) remoteExec ["systemChat", _caller];
    diag_log format ["[LL][DISPATCH] CAS refusé — cooldown %1s.", _rem];
};

if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
    "QG : Livraison de véhicule déjà effectuée. Demande refusée." remoteExec ["systemChat", _caller];
    diag_log "[LL][DISPATCH] VEHICULE refusé — déjà livré (usage unique).";
};

private _state   = missionNamespace getVariable ["LL_HELI_state",    "IDLE"];
private _curPrio = missionNamespace getVariable ["LL_HELI_priority", 0];
private _curType = missionNamespace getVariable ["LL_HELI_type",     ""];

private _interruptibleStates = ["APPROACHING", "CAS", "DELIVERING", "DEPLOYING", "RTB", "RTB_WITH_CARGO"];

private _typePriority = switch (_type) do {
    case "EMBARQUEMENT": { 2 };
    default              { 1 };
};

if (_priority < _typePriority) then { _priority = _typePriority; };

switch (true) do {

    case (_state == "IDLE"): {
        private _approveMsg = switch (_type) do {
            case "LIVRAISON":    { "QG : Livraison de munitions approuvée. Hélicoptère en route."              };
            case "VEHICULE":     { "QG : Livraison de véhicule approuvée. Hélicoptère en route."               };
            case "CAS":          { "QG : Appui aérien CAS approuvé. Hélicoptère en route."                     };
            case "DEBARQUEMENT": { "QG : Renforts approuvés. Hélicoptère en route avec des troupes."           };
            case "EMBARQUEMENT": { "QG : Extraction approuvée. Hélicoptère en route vers la zone de pickup."   };
            default              { "QG : Demande approuvée. Hélicoptère en route."                             };
        };
        _approveMsg remoteExec ["systemChat", _caller];

        if (_type == "VEHICULE") then {
            missionNamespace setVariable ["TAG_VehicleSupport_Delivered", true, true];
        };

        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        diag_log format ["[LL][DISPATCH] Accepté: type=%1 prio=%2", _type, _priority];
    };

    case (_priority > _curPrio && { _state in _interruptibleStates }): {
        private _abortMsg = switch (_curType) do {
            case "CAS":          { "QG : Mission CAS annulée — priorité supérieure."                   };
            case "LIVRAISON":    { "QG : Livraison annulée — mission prioritaire en cours."            };
            case "VEHICULE":     { "QG : Livraison véhicule annulée — mission prioritaire en cours."   };
            case "DEBARQUEMENT": { "QG : Renforts annulés — mission prioritaire en cours."             };
            default              { "QG : Mission en cours annulée — redirection de l'hélicoptère."     };
        };
        _abortMsg remoteExec ["systemChat", 0];

        private _newMsg = switch (_type) do {
            case "EMBARQUEMENT": { "QG : Extraction PRIORITAIRE — hélicoptère redirigé immédiatement." };
            default              { "QG : Nouvelle mission prioritaire acceptée. Hélicoptère redirigé." };
        };
        _newMsg remoteExec ["systemChat", _caller];

        missionNamespace setVariable ["LL_HELI_abort",   true,                              false];
        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        diag_log format ["[LL][DISPATCH] Interruption: %1→%2 prio(%3>%4) état=%5",
            _curType, _type, _priority, _curPrio, _state];
    };

    default {
        private _denyMsg = switch (true) do {
            case (_type == "EMBARQUEMENT" && _curType == "EMBARQUEMENT"): {
                "QG : Extraction déjà en cours. Demande refusée."
            };
            case (_type == "CAS"): {
                format ["QG : Hélicoptère occupé (mission %1 en cours). Appui CAS refusé.", _curType]
            };
            case (_type == "LIVRAISON"): {
                format ["QG : Hélicoptère occupé (mission %1 en cours). Livraison refusée.", _curType]
            };
            case (_type == "VEHICULE"): {
                format ["QG : Hélicoptère occupé (mission %1 en cours). Véhicule refusé.", _curType]
            };
            case (_type == "DEBARQUEMENT"): {
                format ["QG : Hélicoptère occupé (mission %1 en cours). Renforts refusés.", _curType]
            };
            default {
                format ["QG : Hélicoptère occupé (mission %1 en cours). Demande refusée.", _curType]
            };
        };
        _denyMsg remoteExec ["systemChat", _caller];
        diag_log format ["[LL][DISPATCH] Refusé: type=%1 état=%2 prio demandé=%3 prio courante=%4",
            _type, _state, _priority, _curPrio];
    };
};
