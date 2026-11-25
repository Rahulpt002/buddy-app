"""Write one sample payload per topic (from the mock provider) to shared/fixtures/."""
import asyncio
import json
import time
from pathlib import Path

from deskpanel_agent.hub import Hub
from deskpanel_agent.mock import MockProvider

OUT = Path(__file__).resolve().parents[2] / "shared" / "fixtures"


async def main() -> None:
    hub = Hub()
    p = MockProvider()
    hub.add_provider(p)
    await hub.start()
    await hub.stop()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "_meta.json").write_text(json.dumps({"generated_at": int(time.time() * 1000)}) + "\n")
    for topic, frame in hub.latest.items():
        data = json.loads(frame)["data"]
        (OUT / f"{topic}.json").write_text(json.dumps(data, indent=2) + "\n")
        print("wrote", OUT / f"{topic}.json")


if __name__ == "__main__":
    asyncio.run(main())
