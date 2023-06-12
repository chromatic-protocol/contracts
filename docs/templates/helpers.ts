export function contractName(str: string): string | undefined {
  return str.replace('.md', '').split('/').pop()
}

export function contractFileName(str: string): string | undefined {
  return str.replace('.md', '.sol').split('/').pop()
}

export function getSourceUrl(id: string): string {
  return `https://github.com/chromatic-protocol/contracts/tree/main/contracts/${id.replace(
    '.md',
    '.sol'
  )}`
}
