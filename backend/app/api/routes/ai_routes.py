from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/v1/ai", tags=["ai"])


@router.post("/parse-command")
async def parse_command(payload: dict) -> JSONResponse:
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "command": payload.get("command"),
            "parsedActions": [
                {"action": "generate_captions", "confidence": 0.97},
            ],
        },
    )


@router.post("/background-removal")
async def background_removal(payload: dict) -> JSONResponse:
    if not payload.get("clipId"):
        raise HTTPException(status_code=400, detail="clipId is required")

    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "clipId": payload["clipId"],
            "status": "queued",
            "message": "Background removal request accepted.",
        },
    )


@router.post("/generate-captions")
async def generate_captions(payload: dict) -> JSONResponse:
    if not payload.get("audioSource"):
        raise HTTPException(status_code=400, detail="audioSource is required")

    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "requestId": payload.get("requestId", "req-123"),
            "transcript": "This is a mocked caption response.",
            "segments": [
                {
                    "startTime": 0.0,
                    "endTime": 2.0,
                    "text": "This is a mocked caption response.",
                    "confidence": 0.88,
                }
            ],
        },
    )


@router.post("/motion-tracking")
async def motion_tracking(payload: dict) -> JSONResponse:
    if not payload.get("clipId"):
        raise HTTPException(status_code=400, detail="clipId is required")

    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "requestId": payload.get("requestId", "req-456"),
            "trackedPoints": [
                {"time": 0.0, "x": 0.5, "y": 0.5, "confidence": 0.82},
                {"time": 1.0, "x": 0.52, "y": 0.48, "confidence": 0.79},
            ],
        },
    )
