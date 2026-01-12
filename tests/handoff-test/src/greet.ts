export function greet(name: string, formal: boolean = false): string {
  if (formal) {
    return `Good day, ${name}. It is a pleasure to meet you.`;
  }
  return `Hello, ${name}!`;
}
