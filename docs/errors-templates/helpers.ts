export function isNodeType(item: any, nodeTypeName: string): boolean {
  return item.nodeType == nodeTypeName
}

export function hasErrors(item: any) {
  return item.errors?.length > 0
}
