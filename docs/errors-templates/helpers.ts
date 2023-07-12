import { VariableDeclaration } from 'solidity-ast'
import type { DocItemWithContext } from 'solidity-docgen/src/site'

export function isNodeType(item: DocItemWithContext, nodeTypeName: string): boolean {
  return item.nodeType == nodeTypeName
}

export function isLibErrors(name: string): boolean {
  return name == 'Errors'
}

export function hasErrors(item: DocItemWithContext & { errors: any }) {
  return item.errors?.length > 0 || isLibErrors(item.name)
}

export function formatVariable(v: VariableDeclaration): string {
  return [v.typeName?.typeDescriptions.typeString!].concat(v.name || []).join(' ')
}

export function getConstantValue(v: VariableDeclaration): string {
  return (v as any).value?.value
}
