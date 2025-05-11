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
        { "w5a01", "1 - Stolen Valley" },
        { "w2a02", "2 - Freight Frenzy" },
        { "w3a04", "3 - City Seige" },
        { "w1a02", "4 - Eclipse Forest" },
        { "w1b01", "5 - Jungle Inferno" },
        { "w1a01", "6 - Dead atmosphere" },
        { "w5a03", "7 - Meteor Rush" },
        { "w4a01", "8 - Vs. Infinite and Neo Metal Sonic" },
            };     
    settings.Add("mainstory", true, "Autosplitting - Main story acts");
    foreach (var entry in mainstoryActs) settings.Add(entry.Key, true, entry.Value, "mainstory");

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