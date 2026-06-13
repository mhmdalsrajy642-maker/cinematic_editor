from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class AIIntent(str):
    color_grade = "color_grade"
    background_removal = "background_removal"
    captions = "captions"
    motion_tracking = "motion_tracking"
    noise_reduction = "noise_reduction"
    unknown = "unknown"


class AICommandResult(BaseModel):
    intent: AIIntent
    confidence: float
    parameters: Dict[str, Any]
    original_text: str
    language: str = "ar"


class AICommandResponse(BaseModel):
    success: bool
    commands: List[AICommandResult]
    message: Optional[str] = None


_ARABIC_INTENT_MAP = {
    "تلوين": AIIntent.color_grade,
    "تعديلات لونية": AIIntent.color_grade,
    "تحسين الألوان": AIIntent.color_grade,
    "خلفية": AIIntent.background_removal,
    "إزالة الخلفية": AIIntent.background_removal,
    "كتابة الترجمة": AIIntent.captions,
    "توليد ترجمة": AIIntent.captions,
    "تتبع الحركة": AIIntent.motion_tracking,
    "تتبع الأجسام": AIIntent.motion_tracking,
    "خفض الضجيج": AIIntent.noise_reduction,
    "تقليل الضجيج": AIIntent.noise_reduction,
}


def _normalize_text(text: str) -> str:
    return text.strip().lower()


def _map_intent_from_text(text: str) -> AIIntent:
    normalized = _normalize_text(text)
    for phrase, intent in _ARABIC_INTENT_MAP.items():
        if phrase in normalized:
            return intent
    return AIIntent.unknown


class AICommandProcessor:
    def parse_command(self, command_text: str) -> AICommandResponse:
        normalized = _normalize_text(command_text)
        intent = _map_intent_from_text(normalized)

        parameters: Dict[str, Any] = {}
        if intent == AIIntent.color_grade:
            parameters = {"effect": "auto_color_balance"}
        elif intent == AIIntent.background_removal:
            parameters = {"clipId": "unknown", "mode": "auto"}
        elif intent == AIIntent.captions:
            parameters = {"audioSource": "default", "language": "ar"}
        elif intent == AIIntent.motion_tracking:
            parameters = {"clipId": "unknown", "target": "object"}
        elif intent == AIIntent.noise_reduction:
            parameters = {"strength": 0.5}

        result = AICommandResult(
            intent=intent,
            confidence=0.85 if intent != AIIntent.unknown else 0.0,
            parameters=parameters,
            original_text=command_text,
        )

        message = None
        if intent == AIIntent.unknown:
            message = "Could not identify a supported intent from the command."

        return AICommandResponse(
            success=intent != AIIntent.unknown,
            commands=[result],
            message=message,
        )
