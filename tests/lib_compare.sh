#!/usr/bin/env bash
#
# Shared comparison helpers for the NonLinLoc regression tests.
#
# We compare located positions within a tolerance rather than byte-diffing the
# .hyp (a byte diff also fails on every phase residual, which all recompute when
# a location merely nudges). Two location estimators are available, and which one
# is the more stable across platform / compiler / random seed depends on how well
# constrained the event is:
#
#   ml      -- the maximum-likelihood GEOGRAPHIC hypocentre (the single highest
#              PDF sample). For WELL-CONSTRAINED events (sharp PDF: regional data,
#              good coverage) this peak is highly reproducible -- on the Parkfield
#              SSST set, fresh Linux vs the macOS reference differs by <80 m.
#
#   expect  -- the expectation hypocentre from the STAT_GEOG line (the PDF's first
#              moment). For POORLY-CONSTRAINED events (broad/multimodal PDF: deep
#              teleseismic, near sharp interfaces) the ML point can jump between
#              near-equal local maxima across platforms, while the expectation
#              stays put (A. Lomax, 2026). But for well-constrained events the
#              expectation is the noisier of the two, because it integrates the
#              sampling-dependent tails of the scatter cloud (same Parkfield set:
#              up to ~1090 m).
#
# So: ml for the regional tests (local, SSST), expect for the teleseismic (global).
# Positions are always taken in geographic coordinates (deg / km).

# _loc_lines FILE MODE -> one "lat lon depth_km" row per event.
_loc_lines() {
    if [ "${2}" = "expect" ]; then
        grep '^STAT_GEOG' "$1" | awk '{print $3, $5, $7}'      # ExpectLat Long Depth
    else
        grep '^GEOGRAPHIC' "$1" | awk '{print $10, $12, $14}'  # Lat Long Depth
    fi
}

# count_events FILE -> number of located events (GEOGRAPHIC lines).
count_events() { grep -c '^GEOGRAPHIC' "$1"; }

# pair_locations REF OUT MODE -> rows "rlat rlon rz olat olon oz" (events in order).
pair_locations() { paste <(_loc_lines "$1" "$3") <(_loc_lines "$2" "$3"); }

# score_pairs HTOL_M ZTOL_M  (reads paired rows on stdin)
#   -> prints "n max_h_m max_z_m nbad"; exit 0 if nbad==0, else 1.
score_pairs() {
    awk -v htol="$1" -v ztol="$2" '
        NF==6 {
            lat=$1;
            dla=($1-$4); dla=dla<0?-dla:dla;
            dlo=($2-$5); dlo=dlo<0?-dlo:dlo;
            dz=($3-$6);  dz=dz<0?-dz:dz;
            mh=sqrt((dla*111195.0)^2 + (dlo*111195.0*cos(lat*3.14159265/180.0))^2);
            mz=dz*1000.0;
            if (mh>maxh) maxh=mh;
            if (mz>maxz) maxz=mz;
            if (mh>htol || mz>ztol) nbad++;
            n++;
        }
        END {
            printf "%d %.1f %.1f %d", n, maxh+0, maxz+0, nbad+0;
            exit (nbad>0);
        }'
}
