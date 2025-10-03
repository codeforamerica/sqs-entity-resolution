import signal

class LongRunningCallTimeoutEx(Exception):
    pass

def alarm_handler(signum, _):
    raise LongRunningCallTimeoutEx()

def start_alarm_timer(num_seconds):
    signal.alarm(num_seconds)

def cancel_alarm_timer():
    signal.alarm(0)

signal.signal(signal.SIGALRM, alarm_handler)
