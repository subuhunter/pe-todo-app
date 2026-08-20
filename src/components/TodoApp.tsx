"use client";

import { useRef, useState } from "react";
import type { Todo } from "@/types";
import TodoItem from "./TodoItem";
import styles from "./TodoApp.module.css";

export default function TodoApp() {
  // All state lives in memory only -- it resets on refresh, by design.
  const [todos, setTodos] = useState<Todo[]>([]);
  const [draft, setDraft] = useState("");
  const nextId = useRef(1);

  const remaining = todos.filter((todo) => !todo.completed).length;

  function addTodo(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = draft.trim();
    if (!text) return;

    setTodos((current) => [
      ...current,
      { id: String(nextId.current++), text, completed: false },
    ]);
    setDraft("");
  }

  function updateTodo(id: string, text: string) {
    setTodos((current) =>
      current.map((todo) => (todo.id === id ? { ...todo, text } : todo))
    );
  }

  function toggleTodo(id: string) {
    setTodos((current) =>
      current.map((todo) =>
        todo.id === id ? { ...todo, completed: !todo.completed } : todo
      )
    );
  }

  function deleteTodo(id: string) {
    setTodos((current) => current.filter((todo) => todo.id !== id));
  }

  return (
    <section className={styles.app}>
      <header className={styles.header}>
        <h1 className={styles.title}>TODO</h1>
        <p className={styles.subtitle}>
          {todos.length === 0
            ? "Nothing here yet."
            : `${remaining} of ${todos.length} remaining`}
        </p>
      </header>

      <form className={styles.form} onSubmit={addTodo}>
        <input
          className={styles.input}
          type="text"
          value={draft}
          placeholder="What needs doing?"
          aria-label="New task"
          onChange={(event) => setDraft(event.target.value)}
        />
        <button className={styles.addButton} type="submit" disabled={!draft.trim()}>
          Add
        </button>
      </form>

      {todos.length === 0 ? (
        <p className={styles.empty}>Add your first task above to get started.</p>
      ) : (
        <ul className={styles.list}>
          {todos.map((todo) => (
            <TodoItem
              key={todo.id}
              todo={todo}
              onToggle={toggleTodo}
              onUpdate={updateTodo}
              onDelete={deleteTodo}
            />
          ))}
        </ul>
      )}
    </section>
  );
}
