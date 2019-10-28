#!/bin/sh

release_ctl eval --mfa "Boruta.ReleaseTasks.migrate/1" --argv -- "$@"
