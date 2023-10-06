import { VariableDeclaration } from 'solidity-ast'
import type { DocItemWithContext } from 'solidity-docgen/src/site'

export function isNodeType(item: DocItemWithContext, nodeTypeName: string): boolean {
  return item.nodeType == nodeTypeName
}

export function isLibErrors(name: string): boolean {
  return name == 'Errors'
}

export function hasErrors(item: DocItemWithContext & { errors: any }) {
  return item.errors?.length > 0
}

export function formatVariable(v: VariableDeclaration): string {
  return [v.typeName?.typeDescriptions.typeString!].concat(v.name || []).join(' ')
}

export function getConstantValue(v: VariableDeclaration): string {
  return (v as any).value?.value
}

export function dedupeErrors(
  items: (DocItemWithContext & { errors: any })[]
): { errorSelector: string; signature: string }[] {
  const allErrors: { errorSelector: string; signature: string }[] = []
  items.forEach((item) => {
    item.errors?.forEach((err: any) => {
      if (allErrors.filter((allErr) => allErr.errorSelector === err.errorSelector).length === 0) {
        allErrors.push({
          errorSelector: err.errorSelector,
          signature: err.signature.replace('error ', '')
        })
      }
    })
  })

  return allErrors
}
