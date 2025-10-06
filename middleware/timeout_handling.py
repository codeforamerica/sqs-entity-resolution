import signal

from loglib import *

class LongRunningCallTimeoutEx(Exception):
    pass

def alarm_handler(signum, _):
    raise LongRunningCallTimeoutEx()

def start_alarm_timer(num_seconds):
    signal.alarm(num_seconds)

def cancel_alarm_timer():
    signal.alarm(0)

signal.signal(signal.SIGALRM, alarm_handler)

def build_sz_timeout_msg(module_name,
                         class_name,
                         num_seconds,
                         receipt_handle):
    return (
        f'{SZ_TAG} {module_name}.{class_name} :: '
        + f'Long-running Senzing add_record call exceeded {num_seconds} sec.; '
        + f'abandoning and moving on; receipt_handle was: {receipt_handle}')
