/**
                    * ExilelifeServer_system_jobs_process_network_forfeitJobRequest
                    *
                    * Exile Mod
                    * www.exilemod.com
                    * © 2016 Exile Mod Team
                    *
                    * This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
                    * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
                    * 
                    * Permission granted to ExileLife Dev Team to overwrite files and redistribute them
                    *
                    */

                    private["_sessionID","_result","_playerObject","_currentJobs","_jobClassname","_members","_jobExtras","_jobType","_uberJob","_uberJobID","_offeredByPID","_offeredByPlayerSessionID","_offeredByPlayer","_offeredByPlayerMsg","_filePath","_code","_pid","_recipientSessionID","_failedJobs","_reward"];
_sessionID = _this select 0;
_result = false;
try
{
	_playerObject = _sessionID call ExileServer_system_session_getPlayerObject;
	if (isNull _playerObject) then
	{
		throw "Player is Null";
	};
	_currentJobs = _playerObject getVariable ["ExileLifeJobs:Current",[]];
	if (_currentJobs isEqualTo []) then
	{
		if(_playerObject getVariable ["ExileLifeJobMultiJob",""]!= "") then {
			_result = true;
			_jobClassname = _playerObject getVariable ["ExileLifeJobMultiJob",""];
			_playerObject setVariable ["ExileLifeJobMultiJob",nil,true];
			_members = (missionNamespace getVariable format["ExileLifeJobMembers:%1",_jobClassname]);
			_members = _members - [(_playerObject getVariable ["ExileLifePID",-1])];
			missionNamespace setVariable [format["ExileLifeJobMembers:%1",_jobClassname],_members];
			throw "You have left the job queue!"
		};
		throw format["%1 tried to forfeit with no jobs!",name _playerObject];
	};
	_jobClassname = _currentJobs select 0;
	_jobExtras = _currentJobs select 4;
	if !(isClass (configFile >> "CfgJobs" >> _jobClassname)) then
	{
		throw format["Job %1 does not exist in config!",_jobClassname];
	};
	if (isText(configFile >> "CfgJobs" >> _jobClassname >> "givenVehicle")) then {
			_playerObject setVariable ["ExileLifeJobVehicle","",true];
	};
	_jobType = getNumber(configFile >> "CfgJobs" >> _jobClassname >> "jobType");
	switch (_jobType) do {
	    case 1: {
			_uberJob = _jobExtras select 0;
			_uberJobID = _uberJob select 0;
			_offeredByPID = (_uberJob select 7) select 0;
			_offeredByPlayerSessionID = _offeredByPID call ExileLifeServer_system_session_getIDfromDBID;
			_offeredByPlayer = _offeredByPlayerSessionID call ExileServer_system_session_getPlayerObject;
			if !(isNull _offeredByPlayer)then{
			    [_offeredByPlayer,_uberJobID] call ExileLifeServer_system_jobs_uber_removeJobOffer;
				_offeredByPlayerMsg = getText(configFile >> "CfgJobs" >> _jobClassname >> "offeredByPlayerOnForfeitedMsg");
				if !(_offeredByPlayerMsg isEqualTo "") then{
					[_offeredByPlayerSessionID,"toastRequest",["InfoTitleOnly",[_offeredByPlayerMsg]]] call ExileServer_system_network_send_to;
				};
			};
	    };
		default{};
	};
	_filePath = getText (configFile >> "CfgJobs" >> _jobClassname >> "path");
	if !(_filePath isEqualTo "") then
	{
		_code = missionNamespace getVariable [format["ExileLifeServer_system_jobs_scenes_%1_onForfeit",_filePath],""];
		if !(_code isEqualTo "") then
		{
			_result = [_sessionID,_playerObject,_jobClassname] call _code;
			if !(_result isEqualTo "") then
			{
				throw _result;
			};
		};
	};
	if (isNumber (configFile >> "CfgJobs" >> _jobClassname >> "RequiredMembers")) then {
		_playerObject setVariable ["ExileLifeJobMultiJob",nil,true];
		_members = (missionNamespace getVariable format["ExileLifeJobMembers:%1",_jobClassname]);
		missionNamespace setVariable [format["ExileLifeJobMembers:%1",_jobClassname],nil];
		if (typeName _members == "Array") then
		{
			{
				_pid = _x;
				_recipientSessionID = _pid call ExileLifeServer_system_session_getIDfromDBID;
				if(_recipientSessionID!=_sessionID) then {
					[_recipientSessionID,"toastRequest",["ErrorTitleAndText",["Forfeit Job",format["%1 cancelled your groups job!",[_playerObject, "FULL"] call ExileLifeServer_util_player_getName]]]] call ExileServer_system_network_send_to;
					[_recipientSessionID] call ExileLifeServer_system_jobs_process_network_forfeitJobRequest;
				} else {
					[_recipientSessionID,"toastRequest",["ErrorTitleAndText",["Forfeit Job", "The rest of the group has been informed of your decision!"]]] call ExileServer_system_network_send_to;
				};
			}forEach _members;
		};
	};
	_playerObject setVariable ["ExileLifeJobReward",nil];
	_playerObject setVariable ["ExileLifeJobs:Current",[]];
	_failedJobs = _playerObject getVariable ["ExileLifeJobs:Failed",[]];
	_failedJobs pushBack _jobClassname;
	_playerObject setVariable ["ExileLifeJobs:Failed",_failedJobs];
	_reward = getArray(configFile >> "CfgJobs" >> _jobClassname >> "punishmentForfeit");
	if !(_reward isEqualTo []) then
	{
		[_sessionID, _playerObject,_reward] call ExileLifeServer_system_jobs_util_punish;
	};
	if (_sessionID call ExileServer_system_session_isRegisteredId)then{
		[_sessionID,"forfeitJobTask",[_jobClassname]] call ExileServer_system_network_send_to;
	};
	format["updatePlayerJobs:%1:%2:%3:%4",[],_playerObject getVariable ["ExileLifeJobs:Completed",[]],_failedJobs,_playerObject getVariable ["ExileLifePID",-1]] call ExileServer_system_database_query_fireAndForget;
	[_sessionID,_jobClassname] call ExileLifeServer_system_jobs_process_queue_remove;
}
catch
{
	if (_result) then
	{
		[_sessionID,"toastRequest",["ErrorTitleAndText",["Forfeit Job",format["%1",_exception]]]] call ExileServer_system_network_send_to;
	}
	else
	{
		format["exilelifeserver_system_jobs_process_network_forfeitJobRequest: %1",_exception] call ExileLifeServer_util_log;
	};
};
true