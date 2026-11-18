// 시뮬레이터 안 한 프로세스의 벽시계만 FAKE_OFFSET 초만큼 옮긴다 (위젯 카운트다운을 고정 시각으로 그리려고).
#include <time.h>
#include <sys/time.h>
#include <stdlib.h>
#include <stdint.h>

static double off(void) {
    static double o = 0; static int ready = 0;
    if (!ready) { const char *e = getenv("FAKE_OFFSET"); o = e ? atof(e) : 0; ready = 1; }
    return o;
}
static int my_gettimeofday(struct timeval *tv, void *tz) {
    int r = gettimeofday(tv, tz);
    if (r == 0 && tv) {
        long long us = (long long)tv->tv_sec * 1000000LL + tv->tv_usec + (long long)(off() * 1e6);
        tv->tv_sec = (time_t)(us / 1000000LL); tv->tv_usec = (suseconds_t)(us % 1000000LL);
    }
    return r;
}
static int my_clock_gettime(clockid_t c, struct timespec *ts) {
    int r = clock_gettime(c, ts);
    if (r == 0 && ts && c == CLOCK_REALTIME) {
        long long ns = (long long)ts->tv_sec * 1000000000LL + ts->tv_nsec + (long long)(off() * 1e9);
        ts->tv_sec = (time_t)(ns / 1000000000LL); ts->tv_nsec = (long)(ns % 1000000000LL);
    }
    return r;
}
static uint64_t my_clock_gettime_nsec_np(clockid_t c) {
    uint64_t v = clock_gettime_nsec_np(c);
    if (c == CLOCK_REALTIME) v = (uint64_t)((long long)v + (long long)(off() * 1e9));
    return v;
}
static time_t my_time(time_t *t) {
    time_t v = time(NULL) + (time_t)off();
    if (t) *t = v;
    return v;
}
__attribute__((used)) static struct { const void *a; const void *b; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
    { (const void *)my_gettimeofday, (const void *)gettimeofday },
    { (const void *)my_clock_gettime, (const void *)clock_gettime },
    { (const void *)my_clock_gettime_nsec_np, (const void *)clock_gettime_nsec_np },
    { (const void *)my_time, (const void *)time },
};
