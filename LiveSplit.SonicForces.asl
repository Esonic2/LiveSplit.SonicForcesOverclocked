// Autosplitter for Sonic Forces
// Coding: Jujstme
// contacts: just.tribe@gmail.com
// Version: 1.0.0 (Nov 11th, 2022)

state("Sonic Forces") {}

init
{
    // Memory scan for the only signature we need in this game
    var ptr = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize).
        Scan(new SigScanTarget(1, "E8 ???????? 4C 8B 40 78") { OnFound = (p, s, addr) => {
            var tempAddr = addr + p.ReadValue<int>(addr) + 0x4 + 0x3;
            tempAddr += p.ReadValue<int>(tempAddr) + 0x4;
            return tempAddr;
        }});
    if (ptr == IntPtr.Zero)
        throw new NullReferenceException("Sigscanning Failed");

    vars.watchers = new MemoryWatcherList{
        new StringWatcher(new DeepPointer(ptr, 0x80, 0x80, 0x18, 0x0), 250) { Name = "GameMode" },
        new MemoryWatcher<int>(new DeepPointer(ptr, 0x80, 0x80, 0x18, 0x0)) { Name = "GameMode_b", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },

        new StringWatcher(new DeepPointer(ptr, 0x80, 0x80, 0x198, 0x18), 250) { Name = "LevelID" },
        new MemoryWatcher<int>(new DeepPointer(ptr, 0x80, 0x80, 0x198, 0x18)) { Name = "LevelID_b", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },

        new StringWatcher(new DeepPointer(ptr, 0x80, 0x80, 0xA8, 0x20, 0x0), 250) { Name = "State" },
        new MemoryWatcher<int>(new DeepPointer(ptr, 0x80, 0x80, 0xA8, 0x20, 0x0)) { Name = "State_b", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },

        new MemoryWatcher<float>(new DeepPointer(ptr, 0x80, 0x80, 0x1A8, 0x18, 0x0, 0x2C)) { Name = "IGT", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<float>(new DeepPointer(ptr, 0x78, 0x650, 0x10, 0x208, 0x28, 0x1E8, 0x28)) { Name = "DoubleBoost", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
    };

    // Default states
    current.IGT = TimeSpan.Zero;
    current.ActComplete = false;
    current.LevelID = "";
    current.GameMode = "";
    current.State = "";
}

startup
{
    settings.Add("timeOffset", true, "Add 2 seconds to the start time (for Any% runs)");
    settings.SetToolTip("timeOffset", "If enabled, the timer will add 2 seconds to the start time in\norder to comply with speedrun.com rulings for the Any% category.\n\nFor more info, check speedrun.com/sonicforces");
    var mainstoryActs = new Dictionary<string, string>{
        { "w5a01", "1 - Lost Valley" },
        { "w2a02", "2 - Space Port" },
        { "w3a04", "3 - Ghost Town" },
        { "w1a02", "4 - Prison Hall" },
        { "w1b01", "5 - Zavok" },
        { "w1a01", "6 - Egg Gate" },
        { "w5a03", "7 - Arsenal Pyramid" },
        { "w4a01", "8 - Luminous Forest" },
        { "w4b01", "9 - Infinite (1)" },
        { "w5a04", "10 - Green Hill" },
        { "w5b01", "11 - Eggman" },
        { "w3a02", "12 - Park Avenue" },
        { "w4a04", "13 - Casino Forest" },
        { "w4a02", "14 - Aqua Road" },
        { "w3a01", "15 - Sunset Heights" },
        { "w6a02", "16 - Capital City" },
        { "w6b01", "17 - Infinite (2)" },
        { "w2a04", "18 - Chemical Plant" },
        { "w3a03", "19 - Red Gate Bridge" },
        { "w5a02", "20 - Guardian Rock" },
        { "w2a01", "21 - Network Terminal" },
        { "w1a04", "22 - Death Egg" },
        { "w6a01", "23 - Metropolitan Highway" },
        { "w6a03", "24 - Null Space" },
        { "w7a02", "25 - Imperial Tower" },
        { "w7a01", "26 - Mortar Canyon" },
        { "w7b01", "27 - Infinite (3)" },
        { "w7a04", "28 - Iron Fortress" },
        { "w7a03", "29 - Final Judgment" },
        { "w7b02", "30 - Death Egg Robot" }
    };     
    settings.Add("mainstory", true, "Autosplitting - Main story acts");
    foreach (var entry in mainstoryActs) settings.Add(entry.Key, true, entry.Value, "mainstory");

    var eshadowActs = new Dictionary<string, string>{
        { "w3d01", "Act 1" },
        { "w4d01", "Act 2" },
        { "w5d01", "Act 3" }
    };
    settings.Add("shadow", true, "Autosplitting - Episode Shadow");
    foreach (var entry in eshadowActs) settings.Add(entry.Key, true, entry.Value, "shadow");

    // Contants
    vars.GAMEMODE_TITLE = "GameModeTitle";
    vars.GAMEMODE_STAGE = "GameModeStage";
    vars.STATE_PAUSE = "StatePause";
    vars.STATE_PLAY = "StatePlay";
    vars.STATE_STAGEGOALSCENE = "StateStageGoalScene";
    vars.STATE_STAGECLEAR = "StateStageClear";

    // Functions
    vars.SanitizeMWString = (Func<string, string>)(i => vars.watchers[i + "_b"].Current == 0 ? "" : vars.watchers[i].Current );

    // Default variables
    vars.AccumulatedIGT = TimeSpan.Zero;
    vars.startOffset = 2;
    vars.applyOffset = false;
    vars.currentOffset = TimeSpan.Zero;
}

update
{
    // Update the watchers
    vars.watchers.UpdateAll(game);

    current.GameMode = vars.SanitizeMWString("GameMode");
    current.LevelID = vars.SanitizeMWString("LevelID");
    current.State = vars.SanitizeMWString("State");
    current.IGT = current.GameMode == vars.GAMEMODE_STAGE && vars.watchers["IGT"].Current < 50000 ? TimeSpan.FromSeconds(Math.Truncate(vars.watchers["IGT"].Current * 100) / 100) : TimeSpan.Zero;
    current.ActComplete = current.State == vars.STATE_STAGECLEAR;

    // if the timer is not running (eg. a run has been reset) these variables need to be reset
    if (timer.CurrentPhase == TimerPhase.NotRunning)
        vars.AccumulatedIGT = TimeSpan.Zero;

    // Accumulate the time if the IGT resets
    if (old.IGT != TimeSpan.Zero && current.IGT == TimeSpan.Zero)
        vars.AccumulatedIGT += old.IGT;
}

split
{
    if (old.LevelID == "w7b02")
    {
        return settings[old.LevelID] && vars.watchers["DoubleBoost"].Old > 0 && vars.watchers["DoubleBoost"].Current == 0;
    }
    else if (old.LevelID == "w5d01")
    {
        return settings[old.LevelID] && current.State == vars.STATE_STAGEGOALSCENE && old.State != current.State;
    }
    else
    {
        if (old.ActComplete && !current.ActComplete)
            return settings[old.LevelID];
    }
}

start
{
    if (current.GameMode != old.GameMode && current.GameMode == vars.GAMEMODE_STAGE && current.State == "" && current.LevelID != old.LevelID)
    {
        if (current.LevelID == "w3d01")
            return true;
        else if (current.LevelID == "w5a01")
        {
            if (settings["timeOffset"])
            {
                vars.currentOffset = timer.Run.Offset;
                vars.applyOffset = true;
                timer.Run.Offset = TimeSpan.FromSeconds(vars.startOffset);
            } else {
                vars.applyOffset = false;
            }
            return true;
        }
    }
}

gameTime
{
    return current.IGT + vars.AccumulatedIGT;
}

isLoading
{
    return true;
}

reset
{
    return current.GameMode == vars.GAMEMODE_TITLE && current.GameMode != old.GameMode;
}

onStart
{
    if (vars.applyOffset)
        timer.Run.Offset = vars.currentOffset;
}