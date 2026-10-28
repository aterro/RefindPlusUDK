/** @file
  I/O Library.

  Copyright (c) 2006 - 2018, Intel Corporation. All rights reserved.<BR>
  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include "BaseIoLibIntrinsicInternal.h"

__inline__
UINT8
EFIAPI
IoRead8 (
  IN      UINTN                     Port
  )
{
  UINT8 Data;
  __asm__ __volatile__ ("inb %w1, %0" : "=a" (Data) : "Nd" ((UINT16)Port));
  return Data;
}

__inline__
UINT8
EFIAPI
IoWrite8 (
  IN      UINTN                     Port,
  IN      UINT8                     Value
  )
{
  __asm__ __volatile__ ("outb %0, %w1" : : "a" (Value), "Nd" ((UINT16)Port));
  return Value;
}

__inline__
UINT16
EFIAPI
IoRead16 (
  IN      UINTN                     Port
  )
{
  UINT16 Data;
  ASSERT ((Port & 1) == 0);
  __asm__ __volatile__ ("inw %w1, %0" : "=a" (Data) : "Nd" ((UINT16)Port));
  return Data;
}

__inline__
UINT16
EFIAPI
IoWrite16 (
  IN      UINTN                     Port,
  IN      UINT16                    Value
  )
{
  ASSERT ((Port & 1) == 0);
  __asm__ __volatile__ ("outw %0, %w1" : : "a" (Value), "Nd" ((UINT16)Port));
  return Value;
}

__inline__
UINT32
EFIAPI
IoRead32 (
  IN      UINTN                     Port
  )
{
  UINT32 Data;
  ASSERT ((Port & 3) == 0);
  __asm__ __volatile__ ("inl %w1, %0" : "=a" (Data) : "Nd" ((UINT16)Port));
  return Data;
}

__inline__
UINT32
EFIAPI
IoWrite32 (
  IN      UINTN                     Port,
  IN      UINT32                    Value
  )
{
  ASSERT ((Port & 3) == 0);
  __asm__ __volatile__ ("outl %0, %w1" : : "a" (Value), "Nd" ((UINT16)Port));
  return Value;
}
