#!/bin/bash
# Tournament Services Management Script

ACTION="${1:-status}"

case "$ACTION" in
  start)
    echo "Starting all Tournament services..."
    systemctl --user start tournament-backend tournament-frontend tournament-admin
    ;;
  stop)
    echo "Stopping all Tournament services..."
    systemctl --user stop tournament-backend tournament-frontend tournament-admin
    ;;
  restart)
    echo "Restarting all Tournament services..."
    systemctl --user restart tournament-backend tournament-frontend tournament-admin
    ;;
  status)
    echo "Checking Tournament services status..."
    systemctl --user status tournament-backend tournament-frontend tournament-admin --no-pager
    ;;
  logs)
    SERVICE="${2:-backend}"
    echo "Showing logs for tournament-$SERVICE (Ctrl+C to exit)..."
    journalctl --user -u "tournament-$SERVICE" -f
    ;;
  *)
    echo "Usage: ./manage-services.sh {start|stop|restart|status|logs [backend|frontend|admin]}"
    exit 1
    ;;
esac
