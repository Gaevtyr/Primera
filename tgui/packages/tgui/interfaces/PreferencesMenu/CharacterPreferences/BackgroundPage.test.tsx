import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import type {
  AntagonistBackground,
  BackgroundCategory,
  BackgroundEntry,
  BackgroundPreference,
} from '../types';
import { ServerPrefs, useServerPrefs } from '../useServerPrefs';
import { BackgroundPage } from './BackgroundPage';

type SourceEntry = BackgroundEntry & { source_refs?: string[] };
type SourceEntries = Record<string, SourceEntry>;

async function readCatalogFile(name: string) {
  return Bun.file(
    new URL(
      `../../../../../../modular_bandastation/sierra_background/data/${name}.json`,
      import.meta.url,
    ),
  ).json();
}

const [cultures, worlds, factions, religions, wiki, skrell] = await Promise.all(
  [
    readCatalogFile('cultures'),
    readCatalogFile('worlds'),
    readCatalogFile('factions'),
    readCatalogFile('religions'),
    readCatalogFile('wiki_species'),
    readCatalogFile('skrell'),
  ],
);

const catalog: Record<BackgroundCategory, SourceEntries> = {
  culture: { ...cultures.entries, ...wiki.cultures },
  homeworld: { ...worlds.entries, ...wiki.worlds },
  faction: factions.entries,
  subfaction: factions.entries,
  social: skrell.castes,
  religion: { ...religions.entries, ...wiki.religions },
};

type CoreCategory = Exclude<BackgroundCategory, 'subfaction' | 'social'>;

const initialChoices: Record<CoreCategory, string> = {
  culture: 'tsf_solar',
  homeworld: 'Earth',
  faction: 'none',
  religion: 'none',
};
const skrellChoices: Record<CoreCategory, string> = {
  culture: 'skrell_imperial',
  homeworld: 'KverrBalakk',
  faction: 'none',
  religion: 'none',
};
const labels: Record<BackgroundCategory, string> = {
  culture: 'Культура',
  homeworld: 'Место жительства',
  faction: 'Фракция',
  subfaction: 'Подразделение',
  social: 'Каста',
  religion: 'Вера',
};

function preferences(values = initialChoices): BackgroundPreference[] {
  return Object.entries(values).map(([category, value]) => ({
    category: category as BackgroundCategory,
    label: labels[category],
    preference: `sierra_${category}`,
    value,
    choices: Object.keys(catalog[category]),
    notes: '',
    notes_preference: `sierra_${category}_notes`,
    notes_max_length: 4000,
    notes_prompt: `Личные подробности: ${labels[category]}`,
  }));
}

function setData(
  rows = preferences(),
  slot = 1,
  species = 'human',
  antagonist?: AntagonistBackground,
) {
  store.set(gameDataAtom, {
    active_slot: slot,
    character_preferences: { misc: { species } },
    sierra_background: rows,
    sierra_antagonist: antagonist,
  });
}

function TestBackground() {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing.');
  }
  return (
    <ServerPrefs.Provider value={{ ...defaults, sierra_background: catalog }}>
      <BackgroundPage />
    </ServerPrefs.Provider>
  );
}

function sectionFor(row: BackgroundPreference) {
  const section = screen.getByText(row.label).closest('.Section');
  if (!(section instanceof HTMLElement)) {
    throw new Error(`Section ${row.label} is missing.`);
  }
  return section;
}

function plainHtml(html: string) {
  const element = document.createElement('div');
  element.innerHTML = html;
  return element.textContent;
}

afterEach(() => {
  resetStore();
});

describe('BandaStation character background', () => {
  it('shows the backend choices from the complete own lore catalog', () => {
    const rows = preferences();
    setData(rows);
    render(<TestBackground />);

    for (const row of rows) {
      const section = sectionFor(row);
      const selected = catalog[row.category][row.value];
      expect(
        section.querySelector('.Section__titleText')?.textContent,
      ).toContain(selected.name);
      expect(section.textContent).not.toContain(selected.description);

      fireEvent.click(within(section).getByText(row.label));
      for (const choice of row.choices) {
        const name = catalog[row.category][choice].name;
        expect(
          within(section).getAllByText(name, { selector: '.Button__content' })
            .length,
        ).toBeGreaterThan(0);
      }

      fireEvent.click(within(section).getByText('Расширить'));
      expect(section.textContent).toContain(plainHtml(selected.description));
      if (selected.extra) {
        expect(section.textContent).toContain(plainHtml(selected.extra));
      }
    }

    const culture = catalog.culture.tsf_solar;
    expect(culture.description).toContain('\n\n');
    const description = sectionFor(rows[0]).querySelector<HTMLElement>(
      '[style*="white-space: pre-wrap"]',
    );
    expect(description?.textContent).toBe(plainHtml(culture.description));
    expect(description?.style.whiteSpace).toBe('pre-wrap');
  });

  it('renders every own description in full and leaves source references as metadata', () => {
    const rows = preferences();
    setData(rows);
    const view = render(<TestBackground />);

    for (const row of rows) {
      fireEvent.click(within(sectionFor(row)).getByText('Расширить'));
      for (const id of row.choices) {
        row.value = id;
        setData(rows);
        view.rerender(<TestBackground />);
        const section = sectionFor(row);
        const entry = catalog[row.category][id];
        const description = section.querySelector<HTMLElement>(
          '[style*="white-space: pre-wrap"]',
        );
        expect(description?.textContent).toBe(plainHtml(entry.description));
        if (entry.extra) {
          expect(section.textContent).toContain(plainHtml(entry.extra));
        }
        for (const reference of entry.source_refs ?? []) {
          expect(section.textContent).not.toContain(reference);
        }
      }
    }
  });

  it('uses only the options supplied by the backend for the current species', () => {
    const rows = preferences(skrellChoices);
    for (const row of rows) {
      row.choices = [row.value];
    }
    setData(rows, 1, 'skrell');
    render(<TestBackground />);

    for (const row of rows) {
      const section = sectionFor(row);
      fireEvent.click(within(section).getByText(row.label));
      const options = section.querySelectorAll('.Section__content .Button');
      expect(options.length).toBe(1);
      expect(options[0].textContent).toBe(
        catalog[row.category][row.value].name,
      );
    }
  });

  it('sends native preference actions and displays the authoritative new choice', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      setData(rows);
      const view = render(<TestBackground />);

      for (const row of rows) {
        const section = sectionFor(row);
        fireEvent.click(within(section).getByText(row.label));
        const nextId = row.choices.find((id) => id !== row.value)!;
        const next = catalog[row.category][nextId];
        const options = section.querySelectorAll('.Section__content .Button');
        fireEvent.click(options[row.choices.indexOf(nextId)]);
        expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
          preference: row.preference,
          value: nextId,
        });

        row.value = nextId;
        setData(rows);
        view.rerender(<TestBackground />);
        expect(
          section.querySelector('.Section__titleText')?.textContent,
        ).toContain(next.name);
        expect(section.textContent).toContain(plainHtml(next.description));
      }
    } finally {
      sendAct.mockRestore();
    }
  });

  it('shows the server language and naming effects while the culture description is collapsed', () => {
    const rows = preferences();
    rows[0].language_names = ['Общесолнечный', 'Неорусский'];
    rows[0].name_generation = 'Имена из выбранного культурного набора';
    setData(rows);
    render(<TestBackground />);

    const section = sectionFor(rows[0]);
    expect(within(section).queryByText('Скрыть')).toBeNull();
    expect(section.textContent).not.toContain(
      plainHtml(catalog.culture[rows[0].value].description),
    );
    expect(section.textContent).toContain(
      'Языки воспитания: Общесолнечный, Неорусский',
    );
    expect(section.textContent).toContain(
      'Имена: Имена из выбранного культурного набора',
    );
    expect(section.textContent).toContain(
      'Знание языка не гарантирует возможность говорить на нём.',
    );
    expect(section.textContent).toContain(
      'Смена воспитания сохраняет введённое имя.',
    );
    const languages = within(section).getByText('Языки воспитания:');
    const personalDetails = within(section).getByText('Личные подробности');
    expect(
      languages.compareDocumentPosition(personalDetails) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      Array.from(section.querySelectorAll('.Button__content')).map(
        (button) => button.textContent,
      ),
    ).toEqual(['Культура', 'Расширить']);
  });

  it('updates derived effects only from the authoritative backend rows', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      rows[0].language_names = ['Общесолнечный'];
      rows[0].name_generation = 'Первое правило имён';
      setData(rows);
      const view = render(<TestBackground />);

      rows[0].value = 'kssp';
      rows[0].language_names = ['Неорусский'];
      rows[0].name_generation = 'Второе правило имён';
      setData(rows);
      view.rerender(<TestBackground />);

      const section = sectionFor(rows[0]);
      expect(section.textContent).toContain('Языки воспитания: Неорусский');
      expect(section.textContent).toContain('Имена: Второе правило имён');
      expect(section.textContent).not.toContain('Первое правило имён');
      expect(section.textContent).not.toContain('Общесолнечный');
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('handles optional and empty effect data without carrying it between slots or species', () => {
    const rows = preferences();
    rows[0].language_names = ['Общесолнечный'];
    rows[0].name_generation = 'Правило первого слота';
    setData(rows);
    const view = render(<TestBackground />);

    const secondRows = preferences(skrellChoices);
    setData(secondRows, 2, 'skrell');
    view.rerender(<TestBackground />);
    expect(screen.queryByText('Языки воспитания:')).toBeNull();
    expect(screen.queryByText('Имена:')).toBeNull();
    expect(screen.queryByText('Правило первого слота')).toBeNull();

    secondRows[0].language_names = [];
    secondRows[1].language_names = ['Не должно отображаться'];
    secondRows[1].name_generation = 'Не должно отображаться';
    setData(secondRows, 2, 'skrell');
    view.rerender(<TestBackground />);
    expect(sectionFor(secondRows[0]).textContent).toContain(
      'Дополнительные языки не добавляются.',
    );
    expect(screen.queryByText('Имена:')).toBeNull();
    expect(sectionFor(secondRows[1]).textContent).not.toContain(
      'Не должно отображаться',
    );

    secondRows[0].language_names = undefined;
    secondRows[0].name_generation = 'Правило второго слота';
    setData(secondRows, 2, 'skrell');
    view.rerender(<TestBackground />);
    expect(screen.queryByText('Языки воспитания:')).toBeNull();
    expect(sectionFor(secondRows[0]).textContent).toContain(
      'Имена: Правило второго слота',
    );
  });

  it('resets expanded lists and descriptions when the slot or species changes', () => {
    let rows = preferences();
    setData(rows);
    const view = render(<TestBackground />);

    for (const [slot, species] of [
      [2, 'human'],
      [2, 'skrell'],
    ] as const) {
      const section = sectionFor(rows[0]);
      fireEvent.click(within(section).getByText(rows[0].label));
      fireEvent.click(within(section).getByText('Расширить'));
      expect(within(section).getByText('Скрыть')).toBeDefined();

      rows = preferences(species === 'skrell' ? skrellChoices : initialChoices);
      setData(rows, slot, species);
      view.rerender(<TestBackground />);

      const newSection = sectionFor(rows[0]);
      expect(within(newSection).queryByText('Скрыть')).toBeNull();
      expect(
        newSection.querySelectorAll('.Section__content .Button').length,
      ).toBe(0);
    }
  });

  it('keeps personal notes optional and saves each category as plain text on blur', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      setData(rows);
      const view = render(<TestBackground />);

      for (const row of rows) {
        const field = screen.getByLabelText(
          `Личные подробности: ${row.label}`,
        ) as HTMLTextAreaElement;
        expect(field.value).toBe('');
        expect(field.maxLength).toBe(4000);
        const text = `Личный текст: ${row.label}\n<b>Обычный текст</b>`;
        act(() => field.focus());
        fireEvent.change(field, { target: { value: text } });
        expect(sendAct).not.toHaveBeenCalled();

        row.notes = 'Стороннее обновление сохранённого текста';
        setData(rows);
        view.rerender(<TestBackground />);
        expect(field.value).toBe(text);
        expect(field.querySelector('b')).toBeNull();

        act(() => field.blur());
        expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
          preference: row.notes_preference,
          value: text,
        });

        row.notes = text;
        setData(rows);
        view.rerender(<TestBackground />);
        expect(field.value).toBe(text);
        sendAct.mockClear();
      }
    } finally {
      sendAct.mockRestore();
    }
  });

  it('restores the server notes when switching slots or species', () => {
    const rows = preferences();
    rows[0].notes = 'Личные подробности первого персонажа';
    setData(rows);
    const view = render(<TestBackground />);
    const fieldName = `Личные подробности: ${rows[0].label}`;

    expect(
      (screen.getByLabelText(fieldName) as HTMLTextAreaElement).value,
    ).toBe(rows[0].notes);

    const secondRows = preferences();
    secondRows[0].notes = 'Личные подробности второго персонажа';
    setData(secondRows, 2);
    view.rerender(<TestBackground />);
    expect(
      (screen.getByLabelText(fieldName) as HTMLTextAreaElement).value,
    ).toBe(secondRows[0].notes);

    const skrellRows = preferences(skrellChoices);
    skrellRows[0].notes = secondRows[0].notes;
    setData(skrellRows, 2, 'skrell');
    view.rerender(<TestBackground />);
    expect(
      (screen.getByLabelText(fieldName) as HTMLTextAreaElement).value,
    ).toBe(secondRows[0].notes);

    setData(rows, 1);
    view.rerender(<TestBackground />);
    expect(
      (screen.getByLabelText(fieldName) as HTMLTextAreaElement).value,
    ).toBe(rows[0].notes);
  });

  it('uses the whole expand button and keeps it in a wrapping header flow', () => {
    const rows = preferences();
    setData(rows);
    render(<TestBackground />);
    const section = sectionFor(rows[0]);
    const button = within(section).getByLabelText('Описание: Культура');
    const header = button.parentElement!;
    expect(button.classList.contains('Button')).toBe(true);
    expect(button.closest('.Section__buttons')).toBeNull();
    expect(header.style.display).toBe('flex');
    expect(header.style.flexWrap).toBe('wrap');
    const initialStyle = button.getAttribute('style');
    expect(button.getAttribute('aria-expanded')).toBe('false');

    fireEvent.click(button);
    expect(button.getAttribute('aria-expanded')).toBe('true');
    fireEvent.click(button.querySelector('.Button--icon')!);
    expect(button.getAttribute('aria-expanded')).toBe('false');
    fireEvent.click(button.querySelector('.Button__content')!);
    expect(button.getAttribute('aria-expanded')).toBe('true');
    fireEvent.keyDown(button, { key: 'Enter' });
    expect(button.getAttribute('aria-expanded')).toBe('false');
    expect(button.getAttribute('style')).toBe(initialStyle);
  });

  it('follows server ordering and nests the subdivision inside its faction', () => {
    const core = preferences();
    const subfaction: BackgroundPreference = {
      category: 'subfaction',
      preference: 'sierra_subfaction',
      label: 'Подразделение',
      value: 'none',
      choices: ['none'],
    };
    const social: BackgroundPreference = {
      category: 'social',
      preference: 'skrell_caste',
      label: 'Каста',
      value: 'Qerr-Katish',
      choices: Object.keys(skrell.castes),
    };
    const rows = [core[2], subfaction, core[1], social, core[0], core[3]];
    setData(rows, 1, 'skrell');
    const view = render(<TestBackground />);
    const categories = Array.from(
      document.querySelectorAll('[data-background-category]'),
    ).map((section) => section.getAttribute('data-background-category'));
    expect(categories).toEqual([
      'faction',
      'subfaction',
      'homeworld',
      'social',
      'culture',
      'religion',
    ]);
    expect(sectionFor(rows[0]).contains(sectionFor(subfaction))).toBe(true);
    expect(
      sectionFor(social).closest('[data-background-category="faction"]'),
    ).toBeNull();
    expect(screen.getAllByRole('textbox').length).toBe(4);

    setData([core[2], core[1], core[0], core[3]]);
    view.rerender(<TestBackground />);
    expect(screen.queryByText('Каста')).toBeNull();
    expect(screen.queryByText('Подразделение')).toBeNull();
  });

  it('preserves an invalid historical selection and notes until an explicit replacement', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      const residence = rows[1];
      residence.invalid_reason =
        'Для этого вида постоянное проживание не подтверждено.';
      residence.choices = [];
      residence.empty_reason =
        'После фильтрации не осталось подходящих поселений.';
      residence.notes = 'История переезда и станции не должна исчезнуть.';
      setData(rows);
      const view = render(<TestBackground />);
      const section = sectionFor(residence);
      expect(section.textContent).toContain(
        'Сохранённый выбор требует исправления',
      );
      expect(section.textContent).toContain(
        catalog.homeworld[residence.value].name,
      );
      expect(
        (within(section).getByRole('textbox') as HTMLTextAreaElement).value,
      ).toBe(residence.notes);
      fireEvent.click(
        within(section).getByLabelText('Описание: Место жительства'),
      );
      expect(section.textContent).toContain(
        plainHtml(catalog.homeworld[residence.value].description),
      );
      fireEvent.click(within(section).getByText(residence.label));
      expect(section.textContent).toContain(residence.empty_reason);
      expect(sendAct).not.toHaveBeenCalled();
      expect(residence.value).toBe('Earth');

      residence.value = 'retired_unknown_world';
      residence.selected_name = 'Прежнее место жительства';
      setData(rows);
      view.rerender(<TestBackground />);
      expect(section.textContent).toContain(residence.selected_name);
      expect(section.textContent).toContain(
        'Описание выбранного варианта недоступно.',
      );
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('keeps faith unchanged while the faction and dependent options update', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      rows[3].value = rows[3].choices.find((id) => id !== 'none')!;
      const faith = rows[3].value;
      setData(rows);
      const view = render(<TestBackground />);
      fireEvent.click(within(sectionFor(rows[2])).getByText('Фракция'));
      const nextFaction = rows[2].choices.find((id) => id !== rows[2].value)!;
      const choices = sectionFor(rows[2]).querySelectorAll(
        '[data-background-choices="faction"] .Button',
      );
      fireEvent.click(choices[rows[2].choices.indexOf(nextFaction)]);
      rows[2].value = nextFaction;
      rows[1].choices = [];
      setData(rows);
      view.rerender(<TestBackground />);
      expect(sectionFor(rows[3]).textContent).toContain(
        catalog.religion[faith].name,
      );
      expect(rows[3].value).toBe(faith);
      expect(sendAct.mock.calls).toEqual([
        [
          'set_preference',
          { preference: 'sierra_faction', value: nextFaction },
        ],
      ]);
    } finally {
      sendAct.mockRestore();
    }
  });

  it('handles an empty background response without creating choices or actions', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      setData([]);
      const view = render(<TestBackground />);
      expect(
        screen.getByText('Нет доступных настроек предыстории.'),
      ).toBeDefined();
      expect(screen.queryByText('Антагонист')).toBeNull();
      expect(screen.queryByRole('textbox')).toBeNull();
      store.set(gameDataAtom, {});
      view.rerender(<TestBackground />);
      expect(
        screen.getByText('Нет доступных настроек предыстории.'),
      ).toBeDefined();
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('renders only the private antagonist object and commits its separate optional fields', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      setData();
      const view = render(<TestBackground />);
      expect(screen.queryByText('Антагонист')).toBeNull();
      const profile: AntagonistBackground = {
        organization: {
          preference: 'sierra_antagonist_faction',
          value: 'none',
          choices: [
            { id: 'none', name: 'Не задано', description: '' },
            {
              id: 'test_org',
              name: 'Организация из приватных данных',
              description: 'Приватное описание организации.\nПолный текст.',
            },
          ],
        },
        subgroup: {
          preference: 'sierra_antagonist_subfaction',
          value: 'none',
          choices: [{ id: 'none', name: 'Не задано', description: '' }],
        },
        notes: {
          preference: 'sierra_antagonist_notes',
          value: 'Секретный текст анкеты',
          max_length: 1000,
          prompt: 'Как персонаж связан с выбранной организацией?',
        },
      };
      setData(preferences(), 1, 'human', profile);
      view.rerender(<TestBackground />);
      expect(screen.getByText('Антагонист')).toBeDefined();
      expect(document.body.textContent).toContain('видна только вам');
      expect(screen.queryByText('Организация из приватных данных')).toBeNull();
      expect(screen.queryByDisplayValue(profile.notes.value)).toBeNull();
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Антагонист'));
      expect(screen.queryByText(/Подгруппа/)).toBeNull();
      fireEvent.click(screen.getByText('Организация из приватных данных'));
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: profile.organization.preference,
        value: 'test_org',
      });

      profile.organization.value = 'test_org';
      profile.subgroup!.choices.push({
        id: 'test_sub',
        name: 'Подгруппа из приватных данных',
        description: 'Полное описание подгруппы.',
      });
      setData(preferences(), 1, 'human', profile);
      view.rerender(<TestBackground />);
      expect(document.body.textContent).toContain(
        profile.organization.choices[1].description,
      );
      fireEvent.click(screen.getByText('Подгруппа из приватных данных'));
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: profile.subgroup!.preference,
        value: 'test_sub',
      });
      const field = screen.getByLabelText(
        'Личные подробности: Антагонист',
      ) as HTMLTextAreaElement;
      expect(field.maxLength).toBe(1000);
      act(() => field.focus());
      fireEvent.change(field, { target: { value: '<b>Личный текст</b>' } });
      act(() => field.blur());
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: profile.notes.preference,
        value: '<b>Личный текст</b>',
      });
      expect(field.querySelector('b')).toBeNull();

      setData(preferences(), 2);
      view.rerender(<TestBackground />);
      expect(screen.queryByText('Антагонист')).toBeNull();
      expect(screen.queryByDisplayValue('<b>Личный текст</b>')).toBeNull();
    } finally {
      sendAct.mockRestore();
    }
  });
});
