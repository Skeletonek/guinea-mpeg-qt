#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Profile management — returns JSON strings, free with guinea_mpeg_free_string */
const char* guinea_mpeg_available_profiles(void);
const char* guinea_mpeg_load_profile(const char* name);
bool        guinea_mpeg_save_profile(const char* name, const char* json);
bool        guinea_mpeg_delete_profile(const char* name);
void        guinea_mpeg_free_string(const char* s);

/* Ffmpeg utilities */
bool        guinea_mpeg_ffmpeg_available(void);
const char* guinea_mpeg_ffmpeg_version(void);
const char* guinea_mpeg_video_info(const char* path);
const char* guinea_mpeg_generate_preview(const char* path, long long time_ms);

/* Build ffmpeg command line args from profile, returns JSON array or NULL */
const char* guinea_mpeg_build_ffmpeg_command(const char* input, const char* output,
                                              double start_time, double end_time,
                                              const char* profile_json);

/* Mpv backend — returns opaque handle for C++ render context setup */
void* guinea_mpeg_mpv_create(void);
void  guinea_mpeg_mpv_destroy(void* handle);
void* guinea_mpeg_mpv_raw_handle(void* handle);

void  guinea_mpeg_mpv_load_file(void* handle, const char* path);
void  guinea_mpeg_mpv_play(void* handle);
void  guinea_mpeg_mpv_pause(void* handle);
void  guinea_mpeg_mpv_stop(void* handle);
void  guinea_mpeg_mpv_seek(void* handle, int pos_ms);
void  guinea_mpeg_mpv_set_volume(void* handle, int vol);

/* Returns bitmask: 1=position, 2=duration, 4=playing */
int   guinea_mpeg_mpv_process_events(void* handle);

int   guinea_mpeg_mpv_position(const void* handle);
int   guinea_mpeg_mpv_duration(const void* handle);
bool  guinea_mpeg_mpv_is_playing(const void* handle);

#ifdef __cplusplus
}
#endif
