import { expect, test } from "@playwright/test";
import { dayNameOf, openDay, slotList, timeOf } from "./guest-view";
import { apiPort } from "./ports";

const api = `http://127.0.0.1:${apiPort}`;

const topic = "Хочу разобрать архитектуру\nи план релиза";

test("Guest books a free Slot with a topic and the Owner sees it in the upcoming Bookings", async ({
  page,
}) => {
  const created = await fetch(`${api}/event-types`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      id: "review",
      name: "Разбор",
      description: "Подробный разбор задачи",
      durationMinutes: 60,
    }),
  });
  expect(created.status).toBe(201);

  // Book a free Slot two thirds into the window; other scenarios take other Slots.
  const slots = (await (await fetch(`${api}/event-types/review/slots`)).json()) as Array<{
    start: string;
    status: string;
  }>;
  const free = slots.filter((slot) => slot.status === "free");
  const start = free[Math.floor((free.length * 2) / 3)]?.start ?? "";
  const dayName = dayNameOf(start);
  const time = timeOf(start);

  await page.goto("/");
  await page.getByRole("link", { name: "Записаться →" }).click();
  await expect(page.getByRole("heading", { name: "Выберите тип события" })).toBeVisible();
  await expect(page.getByText("Подробный разбор задачи")).toBeVisible();
  const card = page.getByRole("link", { name: "Разбор" });
  await expect(card).toContainText("60 мин");
  await card.click();

  await expect(page.getByRole("heading", { name: "Разбор", level: 1 })).toBeVisible();
  await expect(slotList(page).getByRole("listitem").first()).toBeVisible();

  // Only days of the window are selectable: 14, or 13 when today has no start left.
  const dayButton = /^[а-я]{2}, \d{1,2} [а-я]+$/;
  const selectable = new Set<string>();
  const collect = async () => {
    for (const button of await page.getByRole("button", { name: dayButton }).all()) {
      if (await button.isEnabled()) selectable.add((await button.getAttribute("aria-label")) ?? "");
    }
  };
  await collect();
  const next = page.getByRole("button", { name: "Следующий месяц" });
  if (await next.isEnabled()) {
    await next.click();
    await collect();
    await page.getByRole("button", { name: "Предыдущий месяц" }).click();
  }
  expect(selectable.size).toBeGreaterThanOrEqual(13);
  expect(selectable.size).toBeLessThanOrEqual(14);

  await openDay(page, dayName);
  await expect(page.getByRole("button", { name: "Продолжить" })).toBeDisabled();
  await slotList(page).getByRole("button", { name: time, exact: true }).click();
  await page.getByRole("button", { name: "Продолжить" }).click();

  await page.getByLabel("Имя").fill("Лидия");
  await page.getByLabel("Почта").fill("lidia@example.com");
  const topicField = page.getByLabel("Тема разговора");
  await expect(topicField).toHaveAttribute("required", "");
  await expect(topicField).toHaveAttribute("maxlength", "500");
  await topicField.fill(topic);

  // The typed details survive a trip back to the Slot step.
  await page.getByRole("button", { name: "Назад" }).click();
  await page.getByRole("button", { name: "Продолжить" }).click();
  await expect(page.getByLabel("Тема разговора")).toHaveValue(topic);

  await page.getByRole("button", { name: "Забронировать" }).click();

  // The confirmation is a screen of its own: the calendar, Slots and form are gone.
  const confirmation = page.getByRole("status");
  await expect(confirmation.getByRole("heading", { name: "Бронирование создано" })).toBeVisible();
  await expect(confirmation).toContainText(`${dayName}, ${time}`);
  await expect(slotList(page)).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Забронировать", exact: true })).toHaveCount(0);
  await expect(page.getByText("lidia@example.com")).toHaveCount(0);

  await page.getByRole("button", { name: "Забронировать ещё" }).click();
  await openDay(page, dayName);
  await expect(slotList(page).getByRole("button", { name: `${time} занято` })).toBeDisabled();

  // The next Booking starts from an empty form.
  await slotList(page)
    .getByRole("button", { name: /^\d{2}:\d{2}$/ })
    .first()
    .click();
  await page.getByRole("button", { name: "Продолжить" }).click();
  await expect(page.getByLabel("Имя")).toHaveValue("");
  await expect(page.getByLabel("Почта")).toHaveValue("");
  await expect(page.getByLabel("Тема разговора")).toHaveValue("");

  // The Owner sees the Guest’s Booking in the upcoming list, the topic under name and email.
  await page.goto("/");
  await page.getByRole("link", { name: "Owner" }).click();
  const upcoming = page.getByRole("region", { name: "Предстоящие бронирования" });
  const booking = upcoming.getByRole("listitem").filter({ hasText: "lidia@example.com" });
  await expect(booking).toContainText("Лидия");
  await expect(booking).toContainText("Разбор");
  await expect(booking).toContainText(`${dayName}, ${time}`);
  const shownTopic = booking.getByText("Хочу разобрать архитектуру");
  await expect(shownTopic).toHaveCSS("white-space", "pre-line");
  // innerText keeps the line break, so the topic is shown exactly as typed.
  expect(await shownTopic.innerText()).toBe(topic);
  const lines = await booking.locator("p").allInnerTexts();
  expect(lines.indexOf("lidia@example.com")).toBeGreaterThan(-1);
  expect(lines.indexOf(topic)).toBe(lines.indexOf("lidia@example.com") + 1);
});
