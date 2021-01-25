<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Voter\InfrastructureProvisioner;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Configuration\ConfigurationLoader;
use VPNMinute\Core\Exception\ConfigurationException;
use VPNMinute\Core\Voter\CanVote;
use VPNMinute\Core\Voter\InfrastructureProvisioner\ConfigurationVoter;

class ConfigurationVoterSpec extends ObjectBehavior
{
    public const VALID_CONFIGURATION = [
        ConfigurationVoter::INFRASTUCTURE_TOOL_ENABLED_KEY => self::VALID_CONFIGURATION_CONTENT,
    ];
    public const VALID_CONFIGURATION_CONTENT = ['test', 'test2'];
    public const INVALID_CONFIGURATION = ['dummy'];

    public function let(ConfigurationLoader $configurationLoader)
    {
        $configurationLoader->getInfrastructureProvisionerOptions()->willReturn(self::VALID_CONFIGURATION);

        $this->beConstructedWith($configurationLoader);
    }

    public function it_is_initializable()
    {
        $this->shouldBeAnInstanceOf(ConfigurationVoter::class);
    }

    public function it_can_vote()
    {
        $this->shouldImplement(CanVote::class);
    }

    public function it_throws_an_exception_when_enable_key_is_missing_from_configuration($configurationLoader)
    {
        $configurationLoader->getInfrastructureProvisionerOptions()->willReturn(self::INVALID_CONFIGURATION);

        $this->shouldThrow(ConfigurationException::class)->during('vote', ['']);
    }

    public function it_votes_by_returning_configuration()
    {
        $this->vote('')->shouldReturn(self::VALID_CONFIGURATION_CONTENT);
    }

    public function it_returns_what_subject_it_has_knowledge_on()
    {
        $this->hasKnowledgeOn('infrastructureProvisioner')->shouldReturn(true);
        $this->hasKnowledgeOn('test')->shouldReturn(false);
    }
}
