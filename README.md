# VB_DPC4_TRACES
DPC4 ChampSim traces (xz) split into <50MB parts `X.xz.pN` + `X.xz.sha256`.

    bash Unpack_traces.sh            # rebuild all X.xz, verify sha256
    bash pack_traces.sh --dry-run    # split+reassemble+cmp, touches nothing

Dirs: DPC4_SPEC DPC4_GAP DPC4_Ligra DPC4_AIML. Part name = trace name + .pN, same stem.
