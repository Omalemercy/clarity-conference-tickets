import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Test ticket purchase",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'buy-ticket', [], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify ticket info
    let infoBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'get-ticket-info', [
        types.principal(wallet1.address)
      ], deployer.address)
    ]);
    
    assertEquals(infoBlock.receipts[0].result.expectSome().checked_in, false);
    assertEquals(infoBlock.receipts[0].result.expectSome().refunded, false);
  },
});

Clarinet.test({
  name: "Test ticket check-in",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First buy a ticket
    let buyBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'buy-ticket', [], wallet1.address)
    ]);
    
    // Then check in the ticket
    let checkInBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'check-in-ticket', [
        types.principal(wallet1.address)
      ], deployer.address)
    ]);
    
    checkInBlock.receipts[0].result.expectOk();
    
    // Verify checked-in status
    let infoBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'get-ticket-info', [
        types.principal(wallet1.address)
      ], deployer.address)
    ]);
    
    assertEquals(infoBlock.receipts[0].result.expectSome().checked_in, true);
  },
});

Clarinet.test({
  name: "Test ticket refund within window",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Buy ticket
    let buyBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'buy-ticket', [], wallet1.address)
    ]);
    
    // Request refund
    let refundBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'request-refund', [], wallet1.address)
    ]);
    
    refundBlock.receipts[0].result.expectOk();
    
    // Verify refund status
    let infoBlock = chain.mineBlock([
      Tx.contractCall('conference-ticket', 'get-ticket-info', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    assertEquals(infoBlock.receipts[0].result.expectSome().refunded, true);
  },
});
