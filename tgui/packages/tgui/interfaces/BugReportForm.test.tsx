import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from '../events/act';
import { gameDataAtom, resetStore, store } from '../events/store';

import { BugReportForm } from './BugReportForm';

const details = {
  title: 'Сломанная дверь',
  expected_behavior: 'Дверь открывается',
  description: 'Дверь остаётся закрытой',
  consequences: 'Нельзя выйти',
  steps: 'Нажать на дверь',
  log: '<test> && "quoted"',
};

function setData(fields = {}, sending = false) {
  store.set(gameDataAtom, {
    report_details: fields,
    sending,
    title_limit: 256,
    text_limit: 4096,
    log_limit: 8192,
  });
}

afterEach(resetStore);

describe('BugReportForm', () => {
  it('blocks incomplete reports', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData();
    render(<BugReportForm />);
    fireEvent.click(screen.getByText('Опубликовать на GitHub'));
    expect(sendAct).not.toHaveBeenCalled();
    sendAct.mockRestore();
  });

  it('publishes the visible fields directly including unmodified logs', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData(details);
    render(<BugReportForm />);
    fireEvent.change(screen.getByLabelText('Заголовок'), {
      target: { value: 'Новое название' },
    });
    fireEvent.click(screen.getByText('Опубликовать на GitHub'));
    expect(sendAct).toHaveBeenCalledWith('confirm', {
      ...details,
      title: 'Новое название',
    });
    sendAct.mockRestore();
  });

  it('blocks duplicate submissions and cancellation while sending', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData(details, true);
    render(<BugReportForm />);
    fireEvent.click(screen.getByText('Опубликовать на GitHub'));
    fireEvent.click(screen.getByText('Отмена'));
    expect(sendAct).not.toHaveBeenCalled();
    sendAct.mockRestore();
  });
});
