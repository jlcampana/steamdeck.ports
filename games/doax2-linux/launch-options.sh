# --- Opciones de doax2 (de games/doax2-linux/launch-options.sh) ---
# Las mismas que pasa el lanzador de Windows (src/launcher_public.cpp,
# Launch()) con sus valores por defecto, pero con Vulkan (Native) y sin las
# opciones solo de D3D12. Se cambian con variables de entorno (en Steam:
# Propiedades → Opciones de lanzamiento, p. ej. «DOAX2_FPS=30 %command%»):
#   DOAX2_FPS=60|30         60 (por defecto, como el lanzador) o 30, el original
#   DOAX2_FULLSCREEN=1|0    pantalla completa (por defecto 1)
#   DOAX2_WIDTH/HEIGHT      resolución (por defecto 1280x720, como el lanzador)
#   DOAX2_SCALE=1           escala de resolución interna
#   DOAX2_SHADOWS=1|0       sombras dinámicas
#   DOAX2_MSAA=native|emulated|off  antialiasing MSAA 2x (por defecto native;
#                           off = sin MSAA, lo más ligero, mejor con DOAX2_AA=1)
#   DOAX2_AA=0|1|2          FXAA al final: no (por defecto), FXAA, FXAA extremo
#   DOAX2_ANISO=-1..5       filtro anisótropo: juego, no, 1x, 2x, 4x (3, por
#                           defecto), 8x, 16x
#   DOAX2_FPS_OVERLAY=0|1   contador de FPS
# Partidas en userdata/ y fotos en photos/ (dentro de la carpeta del juego).
tf() { [[ "$1" == 1 ]] && echo true || echo false; }
FPS="${DOAX2_FPS:-60}"
N60=0; [[ "$FPS" == 60 ]] && N60=1
# MSAA como el selector del lanzador: Native 2x, Emulated 2x u Off
MSAA="${DOAX2_MSAA:-native}"
NATIVE2X=1; MSAA_OFF=0
case "$MSAA" in
    emulated) NATIVE2X=0 ;;
    off) MSAA_OFF=1 ;;
esac
case "${DOAX2_AA:-0}" in 1) AA=fxaa ;; 2) AA=fxaa_extreme ;; *) AA=none ;; esac
W="${DOAX2_WIDTH:-1280}"; H="${DOAX2_HEIGHT:-720}"
OPTS=(
    --game_data_root="$HERE/game"
    --user_data_root="$HERE/userdata"
    --gpu_plugin=xenos --gpu_backend=vulkan
    --vulkan_allow_present_mode_immediate=false
    --window_width="$W" --window_height="$H"
    --video_mode_width="$W" --video_mode_height="$H"
    --resolution_scale="${DOAX2_SCALE:-1}"
    --anisotropic_override="${DOAX2_ANISO:-3}"
    --native_2x_msaa="$(tf $NATIVE2X)"
    --doax2_native_markers=true --gpu_force_1x_msaa="$(tf $MSAA_OFF)"
    --gpu_native_tiling=true --gpu_native_clears=true --gpu_native_transfer_elision=true
    --vsync=true
    --video_mode_refresh_rate="$( ((N60)) && echo 120 || echo 60)"
    --vblank_counter_rate_multiplier=1
    --doax2_engine_60fps="$(tf $N60)"
    --doax2_shadow_quality="$( [[ "${DOAX2_SHADOWS:-1}" == 1 ]] && echo 3 || echo 0)"
    --doax2_music_volume_bridge=true
    --gpu_allow_invalid_fetch_constants=true
    --fullscreen="$(tf "${DOAX2_FULLSCREEN:-1}")"
    --doax2_fps_overlay="$(tf "${DOAX2_FPS_OVERLAY:-0}")"
    --swap_post_effect="$AA"
    --execute_unclipped_draw_vs_on_cpu=true --execute_unclipped_draw_vs_on_cpu_with_scissor=true
    --gpu_display_locked_vblank=true --gpu_precise_vblank_timer=true
    --present_ui_with_guest_frames=true
    --doax2_native60_counter_scan=false
    --xmp_keep_song_across_playlists=false
    --readback_resolve=fast --readback_resolve_frame_only=true
    --hires_resolve_capture=true --hires_resolve_capture_aspect=1.5
    --hires_resolve_capture_fxaa=false --hires_resolve_capture_supersample=false
    --doax2_hires_photos=true
    --doax2_money_multiplier=1
    --mnk_mode=true --mnk_mouse=false
    # Teclas del lanzador de Windows (kKeyActions); las del SDK son otras
    --keybind_a=Space --keybind_b=Backspace --keybind_x=F --keybind_y=R
    --keybind_left_shoulder=Q --keybind_right_shoulder=E
    --keybind_left_trigger=Z --keybind_right_trigger=C
    --keybind_back=Tab --keybind_start=Return
    --keybind_lstick_press=V --keybind_rstick_press=H
    --keybind_lstick_up=W --keybind_lstick_down=S --keybind_lstick_left=A --keybind_lstick_right=D
    --keybind_rstick_up=I --keybind_rstick_down=K --keybind_rstick_left=J --keybind_rstick_right=L
    --keybind_dpad_up=Up --keybind_dpad_down=Down --keybind_dpad_left=Left --keybind_dpad_right=Right
)
if ((N60)); then
    OPTS+=(--doax2_native60_tick_scale=0.5
           --doax2_native60_menu_transition_scale=2 --doax2_native60_menu_window_scale=4
           --doax2_native60_menu_repeat_scale=2)
fi
exec "$HERE/doax2" "${OPTS[@]}" "$@"
