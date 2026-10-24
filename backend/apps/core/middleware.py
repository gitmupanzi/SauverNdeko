from django.conf import settings
from django.http import HttpResponse


class CorsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = (
            HttpResponse(status=204)
            if request.method == "OPTIONS"
            else self.get_response(request)
        )
        origin = request.headers.get("Origin")
        if origin in settings.CORS_ALLOWED_ORIGINS:
            response["Access-Control-Allow-Origin"] = origin
            response["Vary"] = "Origin"
            response["Access-Control-Allow-Headers"] = (
                "Authorization,Content-Type,Accept"
            )
            response["Access-Control-Allow-Methods"] = (
                "GET,POST,PUT,PATCH,DELETE,OPTIONS"
            )
        return response
