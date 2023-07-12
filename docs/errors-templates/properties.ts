import { ErrorDefinition } from 'solidity-ast'
import { findAll } from 'solidity-ast/utils'
import type { DocItemContext } from 'solidity-docgen/src/site'

export function errors({ item }: DocItemContext): ErrorDefinition[] | undefined {
  return [...findAll('ErrorDefinition', item)]
}
