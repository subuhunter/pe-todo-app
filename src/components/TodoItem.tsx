"use client";

import { useState } from "react";
import type { Todo } from "@/types";
import styles from "./TodoItem.module.css";

interface TodoItemProps {
  todo: Todo;
  onToggle: (id: string) => void;
  onUpdate: (id: string, text: string) => void;
  onDelete: (id: string) => void;
}

export default function TodoItem({
  todo,
  onToggle,
  onUpdate,
  onDelete,
}: TodoItemProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [draft, setDraft] = useState(todo.text);

  function startEditing() {
    setDraft(todo.text);
    setIsEditing(true);
  }

  function cancelEditing() {
    setDraft(todo.text);
    setIsEditing(false);
  }

  function saveEdit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = draft.trim();
    // An empty edit is treated as a no-op rather than deleting the task.
    if (!text) {
      cancelEditing();
      return;
    }
    onUpdate(todo.id, text);
    setIsEditing(false);
  }

  if (isEditing) {
    return (
      <li className={styles.item}>
        <form className={styles.editForm} onSubmit={saveEdit}>
          <input
            className={styles.editInput}
            type="text"
            value={draft}
            autoFocus
            aria-label="Edit task"
            onChange={(event) => setDraft(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Escape") cancelEditing();
            }}
          />
          <button className={styles.saveButton} type="submit">
            Save
          </button>
          <button
            className={styles.cancelButton}
            type="button"
            onClick={cancelEditing}
          >
            Cancel
          </button>
        </form>
      </li>
    );
  }

  return (
    <li className={styles.item}>
      <label className={styles.label}>
        <input
          className={styles.checkbox}
          type="checkbox"
          checked={todo.completed}
          onChange={() => onToggle(todo.id)}
        />
        <span className={todo.completed ? styles.textDone : styles.text}>
          {todo.text}
        </span>
      </label>

      <div className={styles.actions}>
        <button
          className={styles.editButton}
          type="button"
          onClick={startEditing}
        >
          Edit
        </button>
        <button
          className={styles.deleteButton}
          type="button"
          onClick={() => onDelete(todo.id)}
        >
          Delete
        </button>
      </div>
    </li>
  );
}
