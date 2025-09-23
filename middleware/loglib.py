import logging
import os
import sys

AWS_TAG =   '[AWS] '
SZ_TAG =    '[SZ] '
DLQ_TAG =   '[DLQ] '

_instantiated_loggers = {}

LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

def retrieve_logger(tag='default'):
    global _instantiated_loggers
    if tag in _instantiated_loggers:
        return _instantiated_loggers[tag]
    else:
        x = logging.getLogger(tag)
        x.setLevel(LOG_LEVEL)
        handler = logging.StreamHandler()
        fmt = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] ' \
            '[%(filename)s:%(lineno)s] %(message)s')
        handler.setFormatter(fmt)
        x.addHandler(handler)
        _instantiated_loggers[tag] = x
        return x
