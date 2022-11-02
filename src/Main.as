bool permissionsOkay = false;
ReplaysRoot@ replaysRoot;

void Main() {
    CheckRequiredPermissions();
    @replaysRoot = ReplaysRoot();
    startnew(TestRipGhosts);
    startnew(CreateGhostsDir);
    startnew(AutoSaveReplaysCoro);
}

const string GhostDir = IO::FromUserGameFolder("Replays/Ghosts");
void CreateGhostsDir() {
    if (!IO::FolderExists(GhostDir)) {
        IO::CreateFolder(GhostDir);
    }
}

bool ignoreCall = false;
bool Ghost_Upload(CMwStack &in stack, CMwNod@ nod) {
    if (ignoreCall) return true;
    auto ah = stack.CurrentString();
    print('additional headers: ' + ah);
    auto url = stack.CurrentString(2);
    print('url: ' + url);
    auto g = stack.CurrentNod(1);
    ExploreNod(g);
    auto dfm = cast<CGameDataFileManagerScript>(nod);
    if (dfm !is null) {
        ignoreCall = true;
        dfm.Ghost_Upload("http://localhost:8888", cast<CGameGhostScript>(stack.CurrentNod(1)), ah);
        ignoreCall = false;
        print('ghost uploaded');
    } else {
        print('ghost could not be cast');
    }
    return true;
}

// note: handles both Map_SetNewRecord_v2 and Map_SetNewRecord -- be careful of args
bool Map_SetNewRecord_v2(CMwStack &in stack, CMwNod@ nod) {
    if (ignoreCall) return true;
    auto ghost = cast<CGameGhostScript>(stack.CurrentNod());
    print("ghost is null: " + (ghost is null ? 't' : 'f'));
    return true;
}

void TestRipGhosts() {
    // Dev::InterceptProc("CGameDataFileManagerScript", "Ghost_Upload", Ghost_Upload);
    // Dev::InterceptProc("CGameScoreAndLeaderBoardManagerScript", "Map_SetNewRecord_v2", Map_SetNewRecord_v2);
    // Dev::InterceptProc("CGameScoreAndLeaderBoardManagerScript", "Map_SetNewRecord", Map_SetNewRecord_v2);

    // GetApp().BasicDialogs.DialogSaveAs_OnValidate();
    // GetApp().BasicDialogs.

    // auto x = cast<CGameManiaPlanet>(GetApp());
    // auto tmTitle = x.ManiaTitles[1];
    // @tmTitle.MenuBgReplayFid = x.ReplayRecordInfos[4];

    // string name = GetApp().Network.ClientManiaAppPlayground.LocalUser.Name;
    // auto players = GetApp().CurrentPlayground.Players;
    // for (uint i = 0; i < players.Length; i++) {
    //     if (name == players[i].User.Name) {
    //         auto g = GetApp().Network.ClientManiaAppPlayground.ScoreMgr.Playground_GetPlayerGhost(cast<CSmPlayer>(players[i]).ScriptAPI);
    //         print("found player, Playground_GetPlayerGhost returned null? " + (g is null ? 'yes' : 'no'));
    //         break;
    //     }
    // }


    auto editor = cast<CGameEditorMediaTrackerPluginAPI>(GetApp().Editor.PluginAPI);
    auto tracks = editor.Clip.Tracks;
    print("got " + tracks.Length + " tracks");
    for (uint i = 0; i < tracks.Length; i++) {
        for (uint j = 0; j < tracks[i].Blocks.Length; j++) {
            auto track = tracks[i].Blocks[j];
            auto gTrack = cast<CGameCtnMediaBlockEntity>(track);
            if (gTrack !is null) {
                auto nbKeys = gTrack.GetKeysCount();
                print("Track named " + tracks[i].Name + " is has block with " + nbKeys + " keys");
                // for (uint k = 0; k < nbKeys; k++) {
                //     auto item = gTrack.GetKeyTime(k);
                // }
            } else {
                print("Track named " + tracks[i].Name + " is not an entity track.");
                if (i == tracks.Length - 1) {
                    ExploreNod(track);
                }
            }
        }

    }
    // CGameDataFileManagerScript@ dataFileMgr;
    // while (dataFileMgr is null) {
    //     yield();
    //     try {
    //         @dataFileMgr = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr;
    //     } catch {
    //         ; // nothing
    //     }
    // }
    // string[] filenames = { "Autosaves/XertroV_$FFFit's a bit windy up here_PersonalBest_TimeAttack.Replay.Gbx"
    //     , "Autosaves/XertroV_$s$f00Ca$d60st$bb0el$af0lo $0fcAr$3cdco$78dba$a5ele$c3eno $zft Queen_Clown_PersonalBest_TimeAttack.Replay.Gbx"
    //     , "Replays/Penguin Slide_XertroV(00'52''03).Replay.Gbx"
    //     };
    // for (uint i = 0; i < filenames.Length; i++) {
    //     yield();
    //     auto filename = filenames[i];
    //     auto loading = dataFileMgr.Replay_Load(filename);
    //     trace('loading.IsProcessing: ' + (loading.IsProcessing ? 'y' : 'n'));
    //     while (loading.IsProcessing) yield();
    //     if (loading.HasFailed) {
    //         warn('faild to load ghosts - ' + loading.ErrorCode + ' - ' + loading.ErrorType + ' - ' + loading.ErrorDescription);
    //         continue;
    //     }
    //     print("got this many ghosts: " + loading.Ghosts.Length + " from " + filename);
    // }
}

// check for permissions and
void CheckRequiredPermissions() {
    permissionsOkay = Permissions::ViewRecords() && Permissions::PlayRecords()
        && Permissions::CreateLocalReplay() && Permissions::PlayAgainstReplay()
        && Permissions::OpenReplayEditor();
    if (!permissionsOkay) {
        NotifyWarn("You appear not to have club access.\n\nThis plugin won't work, sorry :(.");
        while(true) { sleep(10000); } // do nothing forever
    }
}

CGamePlaygroundUIConfig::EUISequence lastUiStatus = CGamePlaygroundUIConfig::EUISequence::None;

uint lastAutosave = 0;
void AutoSaveReplaysCoro() {
    if (lastAutosave + 5000 > Time::Now) return; // don't autosave within 5s of autosaving
    lastAutosave = Time::Now;
    while (true) {
        yield();
        if (!Setting_AutoSaveReplays) {
            sleep(1000);
            continue;
        }
        CGamePlaygroundUIConfig::EUISequence currUiSeq = CGamePlaygroundUIConfig::EUISequence::None;
        auto pcs = GetPlaygroundClientScriptAPISync(GetApp());
        if (pcs !is null)
            currUiSeq = pcs.UI.UISequence;
        bool sequenceOkay = currUiSeq == CGamePlaygroundUIConfig::EUISequence::UIInteraction || currUiSeq == CGamePlaygroundUIConfig::EUISequence::Podium;
        if (sequenceOkay && currUiSeq != lastUiStatus && pcs !is null) {
            auto replayFileName = "AutosavedReplays/" + Time::Stamp + "-" + GetApp().RootMap.MapName + " " + pcs.LocalUser.Name + ".Replay.gbx";
            warn("Saving replay: " + replayFileName);
            /* SavePrevReplay is not useful in time attack -- it will save nothing.
               It might save the prior round in KO matches.
               // pcs.SavePrevReplay(replayFileName + "-prev" + ".Replay.gbx");
            */
            // in Time Attack it saves all ghosts up to now that the player has observed
            pcs.SaveReplay(replayFileName);
            // startnew(RepackReplayForPlayersGhostsCoro, RepackOpts(replayFileName)); // does not work
        }
        if (currUiSeq != lastUiStatus) {
            warn("updating ui seq. last: " + tostring(lastUiStatus) + ", new: " + tostring(currUiSeq));
            lastUiStatus = currUiSeq;
        }
    }
}

class RepackOpts {
    string fileName;
    string shortFileName;
    RepackOpts(const string &in shortFn) {
        fileName = IO::FromUserGameFolder("Replays/" + shortFn).Replace("\\", "/");
        shortFileName = shortFn;
    }
}

/* this only seems to work if the ghosts come from a source that is already a valid replay for use in play against a replay.
ghosts from other replays don't seem to get saved at all (presumably some validation from the replay saver thing).
this makes sense since those ghosts are recorded locally instead of the high-res version that the server records.
additionally, the c++ can save the local players high res version online (how we get pb ghosts) but the server also uploads, I think.
so the ghosts that we download from nadeo servers are the high quality ones.

additional experiments: removing player cam and the other cam from the replay doesn't invalidate the ghost for repacking. even altering the
amount of the ghost that is shown doesn't seem to matter.
*/
void RepackReplayForPlayersGhostsCoro(ref@ _opts) {
    auto map = GetApp().RootMap;
    if (map is null) {
        UI::ShowNotification("map null", "go to map you're trying to repack", vec4(1, .4, .1, .4), 10000);
        return;
    }
    auto opts = cast<RepackOpts>(_opts);
    if (opts is null) {
        warn("RepackReplayForPlayersGhostsCoro got null opts");
        return;
    }
    auto rf = ReplayFile(opts.fileName);
    if (!rf.exists) {
        warn("RepackReplayForPlayersGhostsCoro replay (" + opts.fileName + ") does not exist");
        return;
    }
    rf.LoadGhostsSync();
    CGameGhostScript@[] playerGhosts = {};
    string playerName = GetPlayerName(GetApp());
    for (uint i = 0; i < rf.ghosts.Length; i++) {
        auto ghost = rf.ghosts[i];
        // if (ghost.Nickname != playerName) continue;
        playerGhosts.InsertLast(ghost);
    }
    print("repacking " + playerGhosts.Length + " ghosts.");
    yield();
    auto dfm = GetDataFileMgrSync(GetApp());
    print("got dfm");
    for (uint i = 0; i < playerGhosts.Length; i++) {
        auto g = playerGhosts[i];
        if (g.Result is null) {
            print('result is null');
            continue;
        }
        if (g.Result.Time <= 0 || g.Result.Time > 86400000) {
            print('g.Result.Time is ' + g.Result.Time);
        } else {
            print('saving ghost');
            auto newReplayFn = "Repacked\\" + opts.shortFileName.ToLower().Replace(".replay.gbx", "-" + g.Nickname + "-" + Text::Format("%02d", i) + "-" + Text::Format("%dms", g.Result.Time) + ".Replay.gbx");
            dfm.Replay_Save(newReplayFn, map, g);
            print("Saved repacked replay: " + newReplayFn);
        }
        dfm.Ghost_Upload("http://localhost:8888", g, "");
        sleep(100);
    }
}



void Notify(const string &in msg) {
    // UI::ShowNotification("Too Many Ghosts", msg, vec4(.1, .8, .5, .3));
    UI::ShowNotification("Too Many Ghosts", msg, vec4(.2, .8, .5, .3));
}

void NotifyWarn(const string &in msg) {
    UI::ShowNotification("Too Many Ghosts", msg, vec4(1, .5, .1, .5), 10000);
}
