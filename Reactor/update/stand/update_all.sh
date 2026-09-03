#!/usr/bin/env bash

UPDATED=0

run_update()
{
    "$@"
    rc=$?

    if [ "$rc" -eq 10 ]; then
        UPDATED=1
        return 0
    fi

    return "$rc"
}

run_update "$HOME/Reactor/update/update_controllers.sh" || exit $?
run_update "$HOME/Reactor/update/update_frontend.sh"    || exit $?
run_update "$HOME/Reactor/update/update_backend.sh"     || exit $?

if [ "$UPDATED" -eq 1 ]; then
    echo "Something was updated. Restarting backend..."
    systemctl --user restart backend.service
else
    echo "Nothing was updated. Backend restart is not needed."
fi