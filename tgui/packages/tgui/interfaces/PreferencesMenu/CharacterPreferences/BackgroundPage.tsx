import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { sanitizeText } from 'tgui/sanitize';
import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';

import type {
  AntagonistBackground,
  AntagonistBackgroundChoice,
  BackgroundEntry,
  BackgroundPreference,
  PreferencesMenuData,
} from '../types';
import { useServerPrefs } from '../useServerPrefs';

export function BackgroundPage() {
  const { data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const rows = data.sierra_background ?? [];
  const faction = rows.find((row) => row.category === 'faction');
  const subfaction = rows.find((row) => row.category === 'subfaction');
  const characterKey = `${data.active_slot}-${data.character_preferences?.misc?.species}`;

  return (
    <Stack vertical>
      {!rows.length && (
        <Stack.Item>
          <NoticeBox>Нет доступных настроек предыстории.</NoticeBox>
        </Stack.Item>
      )}
      {rows
        .filter((row) => row.category !== 'subfaction' || !faction)
        .map((preference) => (
          <Stack.Item key={preference.category}>
            <BackgroundCategory
              key={`${characterKey}-${preference.category}`}
              preference={preference}
              entries={
                serverData?.sierra_background?.[preference.category] ?? {}
              }
              nested={
                preference.category === 'faction' && subfaction ? (
                  <BackgroundCategory
                    key={`${characterKey}-subfaction`}
                    preference={subfaction}
                    entries={serverData?.sierra_background?.subfaction ?? {}}
                  />
                ) : undefined
              }
            />
          </Stack.Item>
        ))}
      {data.sierra_antagonist && (
        <Stack.Item>
          <PrivateAntagonist
            key={characterKey}
            profile={data.sierra_antagonist}
          />
        </Stack.Item>
      )}
    </Stack>
  );
}

function BackgroundCategory(props: {
  preference: BackgroundPreference;
  entries: Record<string, BackgroundEntry>;
  nested?: ReactNode;
}) {
  const { preference, entries, nested } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const [showChoices, setShowChoices] = useState(false);
  const [showDescription, setShowDescription] = useState(false);
  const selected = entries[preference.value];
  const selectedName =
    preference.selected_name ?? selected?.name ?? preference.value;
  const descriptionId = `background-description-${preference.category}`;

  return (
    <Section
      data-background-category={preference.category}
      title={
        <Box
          style={{
            display: 'flex',
            alignItems: 'center',
            flexWrap: 'wrap',
            gap: '0.5em',
          }}
        >
          <Box
            style={{ flex: '1 1 18em', minWidth: 0, overflowWrap: 'anywhere' }}
          >
            <Button
              color="transparent"
              icon={showChoices ? 'chevron-down' : 'chevron-right'}
              aria-expanded={showChoices}
              onClick={() => setShowChoices(!showChoices)}
            >
              {preference.label}
            </Button>
            {' — '}
            {selectedName || 'Не выбрано'}
          </Box>
          <Button
            icon={showDescription ? 'minus' : 'plus'}
            selected={showDescription}
            aria-label={`Описание: ${preference.label}`}
            aria-expanded={showDescription}
            aria-controls={descriptionId}
            style={{ flexShrink: 0, minHeight: '2.2em', margin: 0 }}
            onClick={() => setShowDescription(!showDescription)}
          >
            {showDescription ? 'Скрыть' : 'Расширить'}
          </Button>
        </Box>
      }
    >
      {preference.invalid_reason && (
        <NoticeBox danger>
          <b>Сохранённый выбор требует исправления: {selectedName}.</b>{' '}
          {preference.invalid_reason} Выберите допустимый вариант. Личные
          подробности сохранены.
        </NoticeBox>
      )}
      {showDescription && (
        <Box id={descriptionId}>
          {selected ? (
            <>
              <Box
                style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}
                dangerouslySetInnerHTML={{
                  __html: sanitizeText(selected.description),
                }}
              />
              {!!selected.extra && (
                <Box
                  mt={1}
                  style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}
                  dangerouslySetInnerHTML={{
                    __html: sanitizeText(selected.extra),
                  }}
                />
              )}
            </>
          ) : (
            <Box color="label">Описание выбранного варианта недоступно.</Box>
          )}
        </Box>
      )}
      {showChoices && (
        <Box
          mt={showDescription ? 1 : 0}
          data-background-choices={preference.category}
        >
          {preference.choices.length ? (
            preference.choices.map((id) => (
              <Button
                key={id}
                selected={id === preference.value}
                onClick={() => {
                  act('set_preference', {
                    preference: preference.preference,
                    value: id,
                  });
                  setShowDescription(true);
                }}
                style={{ whiteSpace: 'normal', maxWidth: '100%' }}
              >
                {entries[id]?.name ?? id}
              </Button>
            ))
          ) : (
            <NoticeBox>
              {preference.empty_reason ??
                'Нет доступных вариантов для текущих настроек персонажа.'}
            </NoticeBox>
          )}
        </Box>
      )}
      {nested && (
        <Box
          mt={1}
          pl={1}
          style={{ borderLeft: '2px solid var(--color-primary)', minWidth: 0 }}
        >
          {nested}
        </Box>
      )}
      {preference.category === 'culture' &&
        (preference.language_names || preference.name_generation) && (
          <Box mt={1}>
            {preference.language_names && (
              <Box>
                <b>Языки воспитания:</b>{' '}
                {preference.language_names.length
                  ? preference.language_names.join(', ')
                  : 'Дополнительные языки не добавляются.'}
              </Box>
            )}
            {!!preference.language_names?.length && (
              <Box color="label" fontSize="0.9em">
                Знание языка не гарантирует возможность говорить на нём.
              </Box>
            )}
            {preference.name_generation && (
              <>
                <Box mt={0.5}>
                  <b>Имена:</b> {preference.name_generation}
                </Box>
                <Box color="label" fontSize="0.9em">
                  Смена воспитания сохраняет введённое имя. Для нового имени
                  используйте кнопку генерации.
                </Box>
              </>
            )}
          </Box>
        )}
      {preference.notes_preference && (
        <>
          <Box mt={1} bold>
            Личные подробности
          </Box>
          <Box color="label" mb={0.5}>
            {preference.notes_prompt}
          </Box>
          <TextArea
            fluid
            height="6em"
            aria-label={`Личные подробности: ${preference.label}`}
            value={preference.notes ?? ''}
            maxLength={preference.notes_max_length}
            onBlur={(value) => {
              if (value !== (preference.notes ?? '')) {
                act('set_preference', {
                  preference: preference.notes_preference,
                  value,
                });
              }
            }}
          />
          <Box color="label" fontSize="0.9em" mt={0.5}>
            Необязательно. Сохраняется при выходе из поля. Shift+Enter — новая
            строка.
          </Box>
        </>
      )}
    </Section>
  );
}

function PrivateAntagonist(props: { profile: AntagonistBackground }) {
  const { profile } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const [expanded, setExpanded] = useState(false);
  const subgroup = profile.subgroup;

  return (
    <Section
      data-background-private="antagonist"
      title={
        <Button
          color="transparent"
          icon={expanded ? 'chevron-down' : 'chevron-right'}
          aria-expanded={expanded}
          onClick={() => setExpanded(!expanded)}
        >
          Антагонист
        </Button>
      }
    >
      <Box color="label">
        Необязательно. Эта предыстория видна только вам и не влияет на получение
        роли.
      </Box>
      {expanded && (
        <Box mt={1}>
          <AntagonistChoice label="Организация" choice={profile.organization} />
          {subgroup &&
            (subgroup.choices.length > 1 ||
              subgroup.value !== 'none' ||
              subgroup.invalid_reason) && (
              <Box
                ml={1}
                mt={1}
                pl={1}
                style={{ borderLeft: '2px solid var(--color-primary)' }}
              >
                <AntagonistChoice label="Подгруппа" choice={subgroup} />
              </Box>
            )}
          <Box bold mt={1}>
            Происхождение и связи
          </Box>
          <Box color="label" mb={0.5}>
            {profile.notes.prompt}
          </Box>
          <TextArea
            fluid
            height="5em"
            aria-label="Личные подробности: Антагонист"
            value={profile.notes.value}
            maxLength={profile.notes.max_length}
            onBlur={(value) => {
              if (value !== profile.notes.value) {
                act('set_preference', {
                  preference: profile.notes.preference,
                  value,
                });
              }
            }}
          />
        </Box>
      )}
    </Section>
  );
}

function AntagonistChoice(props: {
  label: string;
  choice: AntagonistBackgroundChoice;
}) {
  const { label, choice } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const selected = choice.choices.find((entry) => entry.id === choice.value);
  const selectedName = choice.selected_name ?? selected?.name ?? choice.value;

  return (
    <Box>
      <Box bold mb={0.5}>
        {label} — {selectedName || 'Не выбрано'}
      </Box>
      {choice.invalid_reason && (
        <NoticeBox danger>
          Сохранённый выбор требует исправления: {selectedName}.{' '}
          {choice.invalid_reason}
        </NoticeBox>
      )}
      {choice.choices.length ? (
        choice.choices.map((entry) => (
          <Button
            key={entry.id}
            selected={entry.id === choice.value}
            style={{ whiteSpace: 'normal', maxWidth: '100%' }}
            onClick={() =>
              act('set_preference', {
                preference: choice.preference,
                value: entry.id,
              })
            }
          >
            {entry.name}
          </Button>
        ))
      ) : (
        <NoticeBox>
          {choice.empty_reason ?? 'Нет доступных вариантов.'}
        </NoticeBox>
      )}
      {selected && (
        <Box
          mt={0.5}
          style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}
        >
          {selected.description}
        </Box>
      )}
    </Box>
  );
}
