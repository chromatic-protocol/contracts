import { DocItemWithContext } from 'solidity-docgen'

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

export function replaceStruct(item: DocItemWithContext) {
  if (item.nodeType == 'StructDefinition') {
    const natspec = item['natspec']
    if (natspec.params) {
      natspec.params.forEach((param) => {
        const member = item.members.find((e) => e.name === param.name)
        param.type = member?.typeDescriptions.typeString
        if (param.description) {
          // replace newline and tab
          param.description = (param.description as string)
            .replace(/\n/gi, '<br />')
            .replace(/  /g, '')
        }
      })
    }
  }
}
