#!/usr/bin/env python3
"""
Verificador de sintaxe LSL para os scripts do Hand & Foot Canasta.

Verifica:
- Parênteses/chaves/colchetes balanceados
- Aspas balanceadas
- Uso de funções ll* conhecidas
- Uso de eventos conhecidos
- Uso de constantes conhecidas
- Estados default e state_entry presentes

Uso: python3 tools/check_lsl.py
"""

import os, re, sys

# ── LSL Functions ───────────────────────────────────────────────────────────────
KNOWN_FUNCTIONS = {
    'llAbs','llAcos','llAddToLandBanList','llAddToLandPassList',
    'llAdjustSoundVolume','llAllowInventoryDrop','llAngleBetween',
    'llApplyImpulse','llApplyRotationalImpulse','llAsin','llAtan2',
    'llAttachToAvatar','llAttachToAvatarTemp','llAvatarOnLinkSitTarget',
    'llAvatarOnSitTarget','llAxes2Rot','llAxisAngle2Rot',
    'llBase64ToInteger','llBase64ToString','llBreakAllLinks',
    'llBreakLink','llCSV2List','llCastRay','llCeil',
    'llClearCameraParams','llClearLinkMedia','llClearPrimMedia',
    'llCloseRemoteDataChannel','llCollisionFilter','llCollisionSound',
    'llCos','llCreateCharacter','llCreateKeyValue','llCreateLink',
    'llDataSizeKeyValue','llDeleteCharacter','llDeleteKeyValue',
    'llDeleteSubList','llDeleteSubString','llDetachFromAvatar',
    'llDetectedGrab','llDetectedGroup','llDetectedKey',
    'llDetectedLinkNumber','llDetectedName','llDetectedOwner',
    'llDetectedPos','llDetectedRot','llDetectedTouchBinormal',
    'llDetectedTouchFace','llDetectedTouchNormal','llDetectedTouchPos',
    'llDetectedTouchST','llDetectedTouchUV','llDetectedType',
    'llDetectedVel','llDialog','llDie','llDumpList2String',
    'llEdgeOfWorld','llEjectFromLand','llEmail','llEscapeURL',
    'llEuler2Rot','llEvict','llExecCharacterCmd','llFabs',
    'llFloor','llForceMouselook','llFrand','llGenerateKey',
    'llGetAccel','llGetAgentInfo','llGetAgentLanguage',
    'llGetAgentList','llGetAgentSize','llGetAlpha','llGetAndResetTime',
    'llGetAnimation','llGetAnimationList','llGetAnimationOverride',
    'llGetAttached','llGetAttachedList','llGetBoundingBox',
    'llGetCameraPos','llGetCameraRot','llGetCenterOfMass',
    'llGetClosestNavPoint','llGetColor','llGetCreator',
    'llGetDate','llGetDisplayName','llGetEnergy','llGetEnv',
    'llGetForce','llGetFreeMemory','llGetFreeURLs','llGetGeometricCenter',
    'llGetHTTPHeader','llGetInventoryCreator','llGetInventoryKey',
    'llGetInventoryName','llGetInventoryNumber','llGetInventoryPermMask',
    'llGetInventoryType','llGetKey','llGetLandOwnerAt',
    'llGetLinkKey','llGetLinkMedia','llGetLinkName',
    'llGetLinkNumber','llGetLinkNumberOfSides','llGetLinkPrimitiveParams',
    'llGetList2CSV','llGetList2Float','llGetList2Integer',
    'llGetList2Key','llGetList2List','llGetList2ListStrided',
    'llGetList2Rot','llGetList2String','llGetList2Vector',
    'llGetListLength','llGetLocalPos','llGetLocalRot',
    'llGetMass','llGetMassMKS','llGetMaxScaleFactor','llGetMemoryLimit',
    'llGetMinScaleFactor','llGetNextAnimation','llGetNotecardLine',
    'llGetNumberOfNotecardLines','llGetNumberOfPrims',
    'llGetNumberOfSides','llGetObjectDesc','llGetObjectName',
    'llGetObjectMass','llGetObjectPermMask','llGetObjectPrimCount',
    'llGetOwner','llGetOwnerKey','llGetParcelDetails',
    'llGetParcelMaxPrims','llGetParcelMusicURL','llGetParcelPrimCount',
    'llGetPhysicsMaterial','llGetPos','llGetPrimitiveParams',
    'llGetPrimMediaParams','llGetRegionAgentCount',
    'llGetRegionCorner','llGetRegionFPS','llGetRegionFlags',
    'llGetRegionName','llGetRegionTimeDilation','llGetRootPosition',
    'llGetRootRotation','llGetRot','llGetScale','llGetScriptName',
    'llGetScriptState','llGetScriptRunning','llGetSimStats',
    'llGetSimulatorHostname','llGetSPMaxMemory','llGetStartParameter',
    'llGetStaticPath','llGetStatus','llGetSubString','llGetSunDirection',
    'llGetTexture','llGetTextureOffset','llGetTextureRot',
    'llGetTextureScale','llGetTime','llGetTimeOfDay','llGetTimestamp',
    'llGetTorque','llGetUnixTime','llGetUsedMemory','llGetUsername',
    'llGetVel','llGetWallclock','llGiveInventory','llGiveInventoryList',
    'llGiveMoney','llGround','llGroundContour','llGroundNormal',
    'llGroundRepel','llGroundSlope','llHTTPRequest',
    'llHTTPResponse','llInsertString','llInstantMessage',
    'llIntegerToBase64','llJson2List','llJsonGetValue',
    'llJsonSetValue','llJsonValueType','llKey2Name',
    'llLinksetDataCountFound','llLinksetDataDelete',
    'llLinksetDataDeleteFound','llLinksetDataListKeys',
    'llLinksetDataRead','llLinksetDataReset','llLinksetDataWrite',
    'llList2CSV','llList2Float','llList2Integer','llList2Json',
    'llList2Key','llList2List','llList2ListStrided','llList2Rot',
    'llList2String','llList2Vector','llListFindList','llListInsertList',
    'llListRandomize','llListReplaceList','llListSort','llListStatistics',
    'llListen','llListenControl','llListenRemove','llLog','llLog10',
    'llLookAt','llLoopSound','llLoopSoundMaster','llLoopSoundSlave',
    'llManageEstateAccess','llMapDestination','llMD5String',
    'llMessageLinked','llMinEventDelay','llModPow','llModifyLand',
    'llMoveToTarget','llNavigateTo','llOffsetTexture','llOpenRemoteDataChannel',
    'llOverMyLand','llOwnerSay','llParcelMediaCommandList',
    'llParcelMediaQuery','llParseString2List','llParseStringKeepNulls',
    'llParticleSystem','llPassCollisions','llPassTouches',
    'llPatrolPoints','llPlaySound','llPlaySoundSlave',
    'llPointAt','llPow','llPreloadSound','llPursue',
    'llPushObject','llReadKeyValue','llRegionSay','llRegionSayTo',
    'llReleaseCamera','llReleaseControl','llReleaseURL',
    'llRemoteDataReply','llRemoteLoadScriptPin',
    'llRemoveFromLandBanList','llRemoveFromLandPassList',
    'llRemoveInventory','llRemoveVehicleFlags','llRequestAgentData',
    'llRequestInventoryData','llRequestPermissions',
    'llRequestSecureURL','llRequestURL','llRequestUsername',
    'llResetAnimationOverride','llResetLandBanList',
    'llResetLandPassList','llResetOtherScript','llResetScript',
    'llResetTime','llReturnObjectByID','llReturnObjectsByOwner',
    'llRezAtRoot','llRezObject','llRezObjectWithParams',
    'llRot2Angle','llRot2Axis','llRot2Euler','llRot2Fwd',
    'llRot2Left','llRot2Up','llRotBetween','llRotLookAt',
    'llRotateTexture','llRotationBetween','llRotateVec',
    'llRound','llSameGroup','llSay','llScaleByFactor',
    'llScaleTexture','llScriptDanger','llScriptProfiler',
    'llSendRemoteData','llServiceObjectKeyValue',
    'llSetAlpha','llSetAnimationOverride','llSetAttached',
    'llSetCameraAtOffset','llSetCameraEyeOffset',
    'llSetCameraParams','llSetClickAction','llSetColor',
    'llSetContentType','llSetDamage','llSetForce',
    'llSetForceAndTorque','llSetHoverHeight','llSetKey',
    'llSetLinkAlpha','llSetLinkCamera','llSetLinkColor',
    'llSetLinkMedia','llSetLinkPrimitiveParams',
    'llSetLinkPrimitiveParamsFast','llSetLinkTexture',
    'llSetLinkTextureAnim','llSetLocalRot','llSetMemoryLimit',
    'llSetObjectDesc','llSetObjectName','llSetObjectPermMask',
    'llSetParcelMusicURL','llSetPayPrice','llSetPhysicsMaterial',
    'llSetPos','llSetPrimitiveParams','llSetPrimMediaParams',
    'llSetRegionPos','llSetRot','llSetScale','llSetScriptState',
    'llSetSoundQueueing','llSetSoundRadius','llSetStatus',
    'llSetText',
    'llSetTexture','llSetTextureAnim','llSetTimerEvent',
    'llSetTorque','llSetTouchText','llSetVehicleFlags',
    'llSetVehicleFloatParam','llSetVehicleRotationParam',
    'llSetVehicleType','llSetVehicleVectorParam','llSetVelocity',
    'llShout','llSin','llSitTarget','llSleep','llSqrt',
    'llStartAnimation','llStartObjectAnimation','llStartSound',
    'llStopAnimation','llStopHover','llStopLookAt',
    'llStopMoveToTarget','llStopObjectAnimation',
    'llStopPointAt','llStopSound','llStringLength',
    'llStringTrim','llSubStringIndex','llTakeCamera',
    'llTakeControls','llTan','llTarget','llTargetOmega',
    'llTargetRemove','llTeleportAgent','llTeleportAgentGlobalCoords',
    'llTeleportAgentHome','llTeleportLindenAgent',
    'llTextBox','llToLower','llToUpper','llTriggerSound',
    'llTriggerSoundLimited','llUnSit','llUnescapeURL',
    'llUpdateCharacter','llUpdateKeyValue','llVecDist',
    'llVecMag','llVecNorm','llVolumeDetect','llWanderWithin',
    'llWhisper','llWind2Sound','llXorBase64Strings',
    'llXorBase64StringsCorrect',
}

KNOWN_EVENTS = {
    'state_entry','state_exit','touch_start','touch_end','touch',
    'collision_start','collision_end','collision',
    'land_collision_start','land_collision_end','land_collision',
    'at_target','not_at_target','at_rot_target','not_at_rot_target',
    'listen','timer','run_time_permissions','changed',
    'attach','dataserver','link_message','money','email',
    'http_request','http_response','remote_data',
    'object_rez','moving_start','moving_end',
    'on_rez','sensor','no_sensor','control',
    'collision_start','collision_end',
}

KNOWN_CONSTANTS = {
    'TRUE','FALSE','PI','TWO_PI','PI_BY_TWO','DEG_TO_RAD','RAD_TO_DEG',
    'SQRT2','ZERO_VECTOR','ZERO_ROTATION','NULL_KEY',
    'LINK_ROOT','LINK_SET','LINK_ALL_OTHERS','LINK_ALL_CHILDREN',
    'LINK_THIS','INVALID_AGENT',
    'INVENTORY_ALL','INVENTORY_NONE','INVENTORY_TEXTURE',
    'INVENTORY_SOUND','INVENTORY_OBJECT','INVENTORY_SCRIPT',
    'INVENTORY_LANDMARK','INVENTORY_CLOTHING','INVENTORY_NOTECARD',
    'INVENTORY_BODYPART','INVENTORY_ANIMATION','INVENTORY_GESTURE',
    'INVENTORY_SETTING','INVENTORY_MATERIAL',
    'CHANGED_INVENTORY','CHANGED_COLOR','CHANGED_SHAPE',
    'CHANGED_SCALE','CHANGED_TEXTURE','CHANGED_LINK',
    'CHANGED_ALLOWED_DROP','CHANGED_OWNER','CHANGED_REGION',
    'CHANGED_TELEPORT','CHANGED_REGION_START','CHANGED_MEDIA',
    'PERMISSION_DEBIT','PERMISSION_TAKE_CONTROLS',
    'PERMISSION_TRIGGER_ANIMATION','PERMISSION_ATTACH',
    'PERMISSION_CHANGE_LINKS','PERMISSION_TRACK_CAMERA',
    'PERMISSION_CONTROL_CAMERA','PERMISSION_SIT_OWNER',
    'PERMISSION_SIT_AGENT','PERMISSION_TELEPORT',
    'PRIM_TEXTURE','PRIM_COLOR','PRIM_SPECULAR','PRIM_NORMAL',
    'PRIM_POSITION','PRIM_ROTATION','PRIM_SIZE','PRIM_TYPE',
    'PRIM_LINK_TARGET','PRIM_NAME','PRIM_DESC',
    'AGENT','ACTIVE','PASSIVE','SCRIPTED',
    'STRING_TRIM','STRING_TRIM_HEAD','STRING_TRIM_TAIL',
    'AGENT_FLYING','AGENT_ATTACHMENTS','AGENT_SITTING',
    'AGENT_MOUSELOOK','AGENT_AWAY','AGENT_BUSY',
    'AGENT_TYPING','AGENT_IN_A_REGION',
    'VEHICLE_TYPE_NONE','VEHICLE_TYPE_SLED',
    'VEHICLE_TYPE_CAR','VEHICLE_TYPE_BOAT',
    'VEHICLE_TYPE_AIRPLANE','VEHICLE_TYPE_BALLOON',
    'VEHICLE_TYPE_MOTORCYCLE',
    'STATUS_PHYSICS','STATUS_ROTATE_X','STATUS_ROTATE_Y',
    'STATUS_ROTATE_Z','STATUS_PHANTOM','STATUS_SANDBOX',
    'STATUS_BLOCK_GRAB','STATUS_DIE_AT_EDGE',
    'STATUS_RETURN_AT_EDGE','STATUS_CAST_SHADOWS',
    'STATUS_BLOCK_GRAB_OBJECT',
    'HTTP_METHOD','HTTP_BODY_MAXLENGTH','HTTP_BODY_TRUNCATED',
    'HTTP_CUSTOM_HEADER','HTTP_PRAGMA_NO_CACHE',
    'HTTP_VERBOSE_THROTTLE','HTTP_USER_AGENT',
    'RC_REJECT_TYPES','RC_DATA_FLAGS','RC_MAX_HITS',
    'RC_DETECT_PHANTOM','RC_REJECT_AGENTS','RC_REJECT_PHYSICAL',
    'RC_REJECT_NONPHYSICAL','RC_REJECT_LAND','RC_REJECT_WATER',
}

def check_lsl_file(filepath):
    """Verifica um arquivo LSL e retorna lista de problemas."""
    issues = []
    filename = os.path.basename(filepath)

    with open(filepath, 'r') as f:
        content = f.read()
        lines = content.split('\n')

    # ── Balanceamento de delimitadores ──────────────────────────────────────
    stack = []
    in_string = False
    in_comment = False
    escape_next = False

    for line_num, line in enumerate(lines, 1):
        in_comment = False
        i = 0
        while i < len(line):
            ch = line[i]

            if escape_next:
                escape_next = False
                i += 1
                continue

            if ch == '\\' and in_string:
                escape_next = True
                i += 1
                continue

            if ch == '/' and i + 1 < len(line):
                if line[i+1] == '/' and not in_string:
                    in_comment = True
                    break
                if line[i+1] == '*' and not in_string:
                    # Block comment start
                    stack.append(('/*', line_num))
                    i += 2
                    continue

            if ch == '*' and i + 1 < len(line) and line[i+1] == '/' and not in_string:
                if stack and stack[-1][0] == '/*':
                    stack.pop()
                    i += 2
                    continue

            if not in_string:
                if ch == '"':
                    in_string = True
                    stack.append(('"', line_num))
                elif ch in '({[':
                    stack.append((ch, line_num))
                elif ch in ')}]':
                    match = {'}': '{', ')': '(', ']': '['}[ch]
                    if stack and stack[-1][0] == match:
                        stack.pop()
                    elif stack and stack[-1][0] == '"':
                        # Closing delimiter inside string — might be ok
                        pass
                    else:
                        expected = stack[-1] if stack else ('?', 0)
                        issues.append(f"Linha {line_num}: '{ch}' sem correspondência (esperava fechar '{expected[0]}' da linha {expected[1]})")
            else:
                if ch == '"':
                    if stack and stack[-1][0] == '"':
                        stack.pop()
                    in_string = False

            i += 1

    # Verificar stack restante
    for item, line_num in stack:
        if item == '"':
            issues.append(f"Linha {line_num}: aspas não fechadas")
        elif item in '({[':
            close = {'{':'}', '(':')', '[':']'}[item]
            issues.append(f"Linha {line_num}: '{item}' não fechado")

    # ── Funções ll* ────────────────────────────────────────────────────────
    ll_calls = re.findall(r'll([A-Z][a-zA-Z0-9_]*)\s*\(', content)
    for func in ll_calls:
        full = 'll' + func
        if full not in KNOWN_FUNCTIONS:
            issues.append(f"Função desconhecida: {full}()")

    # ── Eventos ────────────────────────────────────────────────────────────
    events = re.findall(r'(\w+)\s*\(\s*integer\s+\w+\s*,', content)
    for ev in events:
        if ev in KNOWN_EVENTS:
            pass  # OK

    # ── Estado default ─────────────────────────────────────────────────────
    if 'default' not in content:
        issues.append("Estado 'default' não encontrado")

    if 'state_entry' not in content:
        issues.append("Evento 'state_entry' não encontrado")

    # ── Jump labels ────────────────────────────────────────────────────────
    jumps = re.findall(r'jump\s+(\w+)', content)
    labels = re.findall(r'@(\w+)', content)
    for j in jumps:
        if j not in labels:
            issues.append(f"Jump para label '@{j}' não encontrado")

    # ── Constantes desconhecidas ───────────────────────────────────────────
    # (verificação leve: palavras ALL_CAPS que não são conhecidas)
    caps_words = re.findall(r'\b([A-Z][A-Z_0-9]{2,})\b', content)
    unknown_consts = set()
    for w in caps_words:
        if w not in KNOWN_CONSTANTS and w not in {'NULL_KEY', 'EOF', 'TRUE', 'FALSE'}:
            # Ignorar tipos LSL
            if w not in {'INTEGER','STRING','KEY','VECTOR','ROTATION','FLOAT','LIST'}:
                unknown_consts.add(w)
    # Não reportar como erro — apenas info

    return issues, unknown_consts


def main():
    lsl_dir = 'lsl'
    if not os.path.isdir(lsl_dir):
        print(f"Diretório '{lsl_dir}' não encontrado!")
        sys.exit(1)

    lsl_files = sorted([f for f in os.listdir(lsl_dir) if f.endswith('.lsl')])
    total_issues = 0

    print("╔══════════════════════════════════════════╗")
    print("║  Verificador de Sintaxe LSL               ║")
    print("╚══════════════════════════════════════════╝\n")

    for fname in lsl_files:
        filepath = os.path.join(lsl_dir, fname)
        issues, unknown_consts = check_lsl_file(filepath)

        status = "✅ OK" if not issues else f"⚠ {len(issues)} problema(s)"
        print(f"  {fname}: {status}")

        for issue in issues:
            print(f"    → {issue}")
            total_issues += 1

        if unknown_consts:
            print(f"    ℹ Constantes não reconhecidas: {', '.join(sorted(unknown_consts)[:5])}")

    print(f"\n{'='*50}")
    if total_issues == 0:
        print("✅ Todos os scripts LSL passaram na verificação!")
    else:
        print(f"⚠ {total_issues} problema(s) encontrado(s) nos scripts.")
    print(f"   Arquivos verificados: {len(lsl_files)}")

    return total_issues


if __name__ == '__main__':
    sys.exit(main())
